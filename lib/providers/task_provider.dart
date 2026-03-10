import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';

class TaskProvider extends ChangeNotifier {
  final TaskRepository _repository = TaskRepository();

  String? _userId;
  List<Task> _tasks = const [];
  bool _loading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get isLoading => _loading;
  String? get error => _error;

  void updateUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _tasks = const [];
    if (_userId != null) {
      loadTasks();
    }
  }

  Future<void> loadTasks() async {
    if (_userId == null) return;
    _loading = true;
    notifyListeners();
    try {
      _tasks = await _repository.getAllTasks(_userId!);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<AddTaskResult> addTask({
    required String title,
    String notes = '',
    List<String> subtasks = const [],
    DateTime? dueDate,
    String? dueTime,
    int priority = 1,
    String? tag,
    int reminderOffset = 10,
    RecurrenceType recurrenceType = RecurrenceType.none,
    int recurrenceInterval = 1,
  }) async {
    if (_userId == null) {
      throw StateError('No active user.');
    }

    final now = DateTime.now();
    final task = Task(
      id: const Uuid().v4(),
      userId: _userId!,
      title: title.trim(),
      notes: notes.trim(),
      subtasks: subtasks,
      dueDate: dueDate,
      dueTime: dueTime,
      priority: priority,
      tag: tag,
      reminderOffset: reminderOffset,
      notificationId: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      orderIndex: DateTime.now().millisecondsSinceEpoch,
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceInterval,
      createdAt: now,
      updatedAt: now,
    );

    final result = await _repository.addTask(task);
    if (result == AddTaskResult.success) {
      await loadTasks();
    }
    return result;
  }

  Future<Task?> toggleDone(Task task, bool done) async {
    Task? generatedRecurringTask;
    if (done) {
      generatedRecurringTask = await _repository.markDone(task);
    } else {
      await _repository.markPending(task);
    }
    await loadTasks();
    return generatedRecurringTask;
  }

  Future<void> deleteTask(Task task) async {
    await _repository.deleteTask(task);
    await loadTasks();
  }

  Future<void> restoreTask(Task task) async {
    await _repository.restoreTask(task);
    await loadTasks();
  }

  Future<void> undoComplete(Task originalTask, {Task? generatedRecurringTask}) async {
    await _repository.markPending(originalTask);
    if (generatedRecurringTask != null) {
      await _repository.deleteTask(generatedRecurringTask);
    }
    await loadTasks();
  }

  Future<void> reorderTasks(int oldIndex, int newIndex) async {
    if (_userId == null) return;
    if (oldIndex < 0 || oldIndex >= _tasks.length) return;
    if (newIndex < 0 || newIndex > _tasks.length) return;

    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final updated = List<Task>.from(_tasks);
    final moved = updated.removeAt(oldIndex);
    updated.insert(adjustedIndex, moved);
    _tasks = updated;
    notifyListeners();

    await _repository.reorderTasks(_userId!, _tasks);
    await loadTasks();
  }
}
