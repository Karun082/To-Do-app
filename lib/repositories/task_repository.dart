import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

enum AddTaskResult { success, capReached }

class TaskRepository {
  Future<List<Task>> getTasksForDate(String userId, DateTime date) async {
    final db = await DatabaseService.db;
    final key = DateFormat('yyyy-MM-dd').format(date);
    final rows = await db.query(
      'tasks',
      where: 'user_id = ? AND due_date = ?',
      whereArgs: [userId, key],
      orderBy: 'priority DESC, due_time ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getAllTasks(String userId) async {
    await refreshOverdueStatuses(userId);
    final db = await DatabaseService.db;
    final rows = await db.query(
      'tasks',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'order_index ASC, due_date ASC, due_time ASC',
    );
    final tasks = rows.map(Task.fromMap).toList();
    final now = DateTime.now();
    final oneDayAhead = now.add(const Duration(days: 1));
    for (final task in tasks) {
      if (task.isDone || task.dueDateTime == null) continue;
      final due = task.dueDateTime!;
      if (due.isBefore(oneDayAhead)) {
        await NotificationService.scheduleForTask(task);
      }
    }
    return tasks;
  }

  Future<AddTaskResult> addTask(Task task) async {
    final db = await DatabaseService.db;
    final effectiveOrder = task.orderIndex == 0
        ? DateTime.now().millisecondsSinceEpoch
        : task.orderIndex;
    final toInsert = task.copyWith(orderIndex: effectiveOrder);
    await db.insert('tasks', toInsert.toMap());
    await NotificationService.scheduleForTask(toInsert);
    return AddTaskResult.success;
  }

  Future<void> restoreTask(Task task) async {
    final db = await DatabaseService.db;
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await NotificationService.scheduleForTask(task);
  }

  Future<void> updateTask(Task task) async {
    final db = await DatabaseService.db;
    final updated = task.copyWith();
    await db.update('tasks', updated.toMap(), where: 'id = ?', whereArgs: [task.id]);
    await NotificationService.scheduleForTask(updated);
  }

  Future<void> deleteTask(Task task) async {
    final db = await DatabaseService.db;
    await db.delete('tasks', where: 'id = ?', whereArgs: [task.id]);
    await NotificationService.cancel(task.notificationId);
  }

  Future<Task?> markDone(Task task) async {
    await updateTask(task.copyWith(status: 'done'));
    if (task.isRecurring && task.dueDate != null) {
      final next = task.nextRecurringCopy(const Uuid().v4(), _notificationId());
      await addTask(next);
      return next;
    }
    return null;
  }

  Future<void> markPending(Task task) => updateTask(task.copyWith(status: 'pending'));

  Future<void> refreshOverdueStatuses(String userId) async {
    final db = await DatabaseService.db;
    final rows = await db.query(
      'tasks',
      where: 'user_id = ? AND status != ?',
      whereArgs: [userId, 'done'],
    );

    final now = DateTime.now();
    for (final row in rows) {
      final task = Task.fromMap(row);
      final due = task.dueDateTime;
      if (due == null) continue;

      final shouldBeOverdue = due.isBefore(now);
      final nextStatus = shouldBeOverdue ? 'overdue' : 'pending';
      if (task.status != nextStatus) {
        await db.update(
          'tasks',
          {
            'status': nextStatus,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [task.id],
        );
        await NotificationService.scheduleForTask(task.copyWith(status: nextStatus));
      }
    }
  }

  Future<void> reorderTasks(String userId, List<Task> tasks) async {
    final db = await DatabaseService.db;
    final batch = db.batch();
    for (var i = 0; i < tasks.length; i++) {
      batch.update(
        'tasks',
        {'order_index': i + 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND user_id = ?',
        whereArgs: [tasks[i].id, userId],
      );
    }
    await batch.commit(noResult: true);
  }

  int _notificationId() => DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
}
