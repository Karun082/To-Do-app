import 'dart:convert';

enum RecurrenceType { none, daily, weekly, custom }

RecurrenceType recurrenceTypeFromString(String? value) {
  switch (value) {
    case 'daily':
      return RecurrenceType.daily;
    case 'weekly':
      return RecurrenceType.weekly;
    case 'custom':
      return RecurrenceType.custom;
    default:
      return RecurrenceType.none;
  }
}

String recurrenceTypeToString(RecurrenceType type) {
  switch (type) {
    case RecurrenceType.daily:
      return 'daily';
    case RecurrenceType.weekly:
      return 'weekly';
    case RecurrenceType.custom:
      return 'custom';
    case RecurrenceType.none:
      return 'none';
  }
}

class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    this.notes = '',
    this.dueDate,
    this.dueTime,
    this.status = 'pending',
    this.priority = 1,
    this.tag,
    this.reminderOffset = 10,
    this.notificationId,
    this.subtasks = const [],
    this.orderIndex = 0,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final String notes;
  final DateTime? dueDate;
  final String? dueTime;
  final String status;
  final int priority;
  final String? tag;
  final int reminderOffset;
  final int? notificationId;
  final List<String> subtasks;
  final int orderIndex;
  final RecurrenceType recurrenceType;
  final int recurrenceInterval;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDone => status == 'done';
  bool get isRecurring => recurrenceType != RecurrenceType.none;
  bool get isOverdue => status == 'overdue';

  DateTime? get dueDateTime {
    if (dueDate == null || dueTime == null) return null;
    final parts = dueTime!.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(dueDate!.year, dueDate!.month, dueDate!.day, hour, minute);
  }

  Task copyWith({
    String? title,
    String? notes,
    DateTime? dueDate,
    String? dueTime,
    String? status,
    int? priority,
    String? tag,
    int? reminderOffset,
    int? notificationId,
    List<String>? subtasks,
    int? orderIndex,
    RecurrenceType? recurrenceType,
    int? recurrenceInterval,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      tag: tag ?? this.tag,
      reminderOffset: reminderOffset ?? this.reminderOffset,
      notificationId: notificationId ?? this.notificationId,
      subtasks: subtasks ?? this.subtasks,
      orderIndex: orderIndex ?? this.orderIndex,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Task nextRecurringCopy(String newId, int newNotificationId) {
    if (dueDate == null) {
      throw StateError('Recurring task requires dueDate.');
    }

    final days = switch (recurrenceType) {
      RecurrenceType.daily => recurrenceInterval,
      RecurrenceType.weekly => 7 * recurrenceInterval,
      RecurrenceType.custom => recurrenceInterval,
      RecurrenceType.none => 0,
    };

    final nextDate = dueDate!.add(Duration(days: days));

    return Task(
      id: newId,
      userId: userId,
      title: title,
      notes: notes,
      dueDate: nextDate,
      dueTime: dueTime,
      status: 'pending',
      priority: priority,
      tag: tag,
      reminderOffset: reminderOffset,
      notificationId: newNotificationId,
      subtasks: subtasks,
      orderIndex: orderIndex,
      recurrenceType: recurrenceType,
      recurrenceInterval: recurrenceInterval,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      title: map['title']! as String,
      notes: map['notes'] as String? ?? '',
      dueDate: map['due_date'] == null
          ? null
          : DateTime.parse(map['due_date']! as String),
      dueTime: map['due_time'] as String?,
      status: map['status'] as String? ?? 'pending',
      priority: map['priority'] as int? ?? 1,
      tag: map['tag'] as String?,
      reminderOffset: map['reminder_offset'] as int? ?? 10,
      notificationId: map['notification_id'] as int?,
      subtasks: _decodeSubtasks(map['subtasks_json']),
      orderIndex: map['order_index'] as int? ?? 0,
      recurrenceType: recurrenceTypeFromString(map['recurrence_type'] as String?),
      recurrenceInterval: map['recurrence_interval'] as int? ?? 1,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'notes': notes,
      'due_date': dueDate == null ? null : _dateOnlyIso(dueDate!),
      'due_time': dueTime,
      'status': status,
      'priority': priority,
      'tag': tag,
      'reminder_offset': reminderOffset,
      'notification_id': notificationId,
      'subtasks_json': jsonEncode(subtasks),
      'order_index': orderIndex,
      'recurrence_type': recurrenceTypeToString(recurrenceType),
      'recurrence_interval': recurrenceInterval,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String _dateOnlyIso(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.toIso8601String().split('T').first;
  }

  static List<String> _decodeSubtasks(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is List) {
        return decoded.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
