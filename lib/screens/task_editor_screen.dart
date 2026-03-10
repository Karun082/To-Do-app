import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key});

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagController = TextEditingController();
  final _subtaskController = TextEditingController();
  final List<String> _subtasks = <String>[];

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  int _priority = 1;
  int _reminderOffset = 10;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  int _recurrenceInterval = 1;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty || text.length > 120) {
                  return 'Title must be 1-120 characters';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
              validator: (value) {
                if ((value ?? '').length > 1000) {
                  return 'Notes too long';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _tagController,
              decoration: const InputDecoration(labelText: 'Tag (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    decoration: const InputDecoration(labelText: 'Add subtask'),
                    onSubmitted: (_) => _addSubtask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addSubtask,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_subtasks.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _subtasks
                    .map(
                      (subtask) => Chip(
                        label: Text(subtask),
                        onDeleted: () => setState(() => _subtasks.remove(subtask)),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(
                      _dueDate == null
                          ? 'Pick due date'
                          : DateFormat('yyyy-MM-dd').format(_dueDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(
                      _dueTime == null ? 'Pick due time' : _dueTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Low')),
                DropdownMenuItem(value: 1, child: Text('Medium')),
                DropdownMenuItem(value: 2, child: Text('High')),
              ],
              onChanged: (value) => setState(() => _priority = value ?? 1),
            ),
            DropdownButtonFormField<int>(
              value: _reminderOffset,
              decoration: const InputDecoration(labelText: 'Repeat every (minutes after overdue)'),
              items: const [
                DropdownMenuItem(value: 10, child: Text('10 min')),
                DropdownMenuItem(value: 15, child: Text('15 min')),
                DropdownMenuItem(value: 30, child: Text('30 min')),
              ],
              onChanged: (value) => setState(() => _reminderOffset = value ?? 10),
            ),
            DropdownButtonFormField<RecurrenceType>(
              value: _recurrenceType,
              decoration: const InputDecoration(labelText: 'Recurrence'),
              items: const [
                DropdownMenuItem(value: RecurrenceType.none, child: Text('None')),
                DropdownMenuItem(value: RecurrenceType.daily, child: Text('Daily')),
                DropdownMenuItem(value: RecurrenceType.weekly, child: Text('Weekly')),
                DropdownMenuItem(value: RecurrenceType.custom, child: Text('Custom (days)')),
              ],
              onChanged: (value) =>
                  setState(() => _recurrenceType = value ?? RecurrenceType.none),
            ),
            if (_recurrenceType == RecurrenceType.custom)
              TextFormField(
                initialValue: _recurrenceInterval.toString(),
                decoration: const InputDecoration(labelText: 'Custom interval in days'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _recurrenceInterval = int.tryParse(value) ?? 1,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Save task'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 3650)),
      initialDate: _dueDate ?? now,
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _dueTime = time);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null || _dueTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select due date and due time for notifications.')),
      );
      return;
    }

    final dueTimeString = _dueTime == null
        ? null
        : '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}';

    await context.read<TaskProvider>().addTask(
          title: _titleController.text,
          notes: _notesController.text,
          subtasks: _subtasks,
          dueDate: _dueDate,
          dueTime: dueTimeString,
          priority: _priority,
          tag: _tagController.text.trim().isEmpty ? null : _tagController.text.trim(),
          reminderOffset: _reminderOffset,
          recurrenceType: _recurrenceType,
          recurrenceInterval: _recurrenceInterval,
        );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _addSubtask() {
    final value = _subtaskController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _subtasks.add(value);
      _subtaskController.clear();
    });
  }
}
