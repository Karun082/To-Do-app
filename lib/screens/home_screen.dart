import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';
import 'task_editor_screen.dart';

enum TaskFilter { all, pending, done, overdue }
enum DueGroupFilter { all, today, tomorrow, overdue }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  TaskFilter _filter = TaskFilter.all;
  DueGroupFilter _dueGroup = DueGroupFilter.all;
  int? _priorityFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.ensurePermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = _applyFilter(provider.tasks);
    final canReorder =
        _query.isEmpty &&
        _filter == TaskFilter.all &&
        _dueGroup == DueGroupFilter.all &&
        _priorityFilter == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DailyChip Todo'),
        actions: [
          IconButton(
            onPressed: () async {
              await NotificationService.scheduleTestNotification();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test notification scheduled in 5 seconds')),
              );
            },
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test notification',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TaskEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<TaskProvider>().loadTasks(),
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                onReorder: (oldIndex, newIndex) {
                  if (!canReorder) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clear filters/search to reorder tasks')),
                    );
                    return;
                  }
                  if (oldIndex == 0 || newIndex == 0) return;
                  context.read<TaskProvider>().reorderTasks(oldIndex - 1, newIndex - 1);
                },
                itemCount: tasks.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeader(context, provider, tasks.length, key: const ValueKey<String>('header'));
                  }
                  final task = tasks[index - 1];
                  return _TaskTile(
                    key: ValueKey<String>(task.id),
                    task: task,
                    onAction: _handleTaskAction,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context, TaskProvider provider, int visibleCount, {required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search tasks, notes, or tags',
            ),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _filterChip(TaskFilter.all, 'All'),
              _filterChip(TaskFilter.pending, 'Pending'),
              _filterChip(TaskFilter.done, 'Done'),
              _filterChip(TaskFilter.overdue, 'Overdue'),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _dueChip(DueGroupFilter.all, 'All Dates'),
              _dueChip(DueGroupFilter.today, 'Today'),
              _dueChip(DueGroupFilter.tomorrow, 'Tomorrow'),
              _dueChip(DueGroupFilter.overdue, 'Overdue Date'),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _priorityChip(null, 'All Priority'),
              _priorityChip(2, 'High'),
              _priorityChip(1, 'Medium'),
              _priorityChip(0, 'Low'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            '${provider.tasks.where((t) => t.isDone).length}/${provider.tasks.length} done • $visibleCount visible',
          ),
        ),
        if (visibleCount == 0)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No tasks found for current filters.')),
          ),
      ],
    );
  }

  Widget _filterChip(TaskFilter filter, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
      ),
    );
  }

  Widget _dueChip(DueGroupFilter filter, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: _dueGroup == filter,
        onSelected: (_) => setState(() => _dueGroup = filter),
      ),
    );
  }

  Widget _priorityChip(int? priority, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: _priorityFilter == priority,
        onSelected: (_) => setState(() => _priorityFilter = priority),
      ),
    );
  }

  List<Task> _applyFilter(List<Task> source) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final filtered = source.where((task) {
      final matchesStatus = switch (_filter) {
        TaskFilter.all => true,
        TaskFilter.pending => task.status == 'pending',
        TaskFilter.done => task.status == 'done',
        TaskFilter.overdue => task.status == 'overdue',
      };
      if (!matchesStatus) return false;

      final matchesPriority = _priorityFilter == null || task.priority == _priorityFilter;
      if (!matchesPriority) return false;

      final due = task.dueDateTime;
      final matchesDue = switch (_dueGroup) {
        DueGroupFilter.all => true,
        DueGroupFilter.today => due != null && DateTime(due.year, due.month, due.day) == today,
        DueGroupFilter.tomorrow => due != null && DateTime(due.year, due.month, due.day) == tomorrow,
        DueGroupFilter.overdue => due != null && due.isBefore(now) && !task.isDone,
      };
      if (!matchesDue) return false;

      if (_query.isEmpty) return true;
      final haystack = '${task.title} ${task.notes} ${task.tag ?? ''}'.toLowerCase();
      return haystack.contains(_query);
    }).toList();

    filtered.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return filtered;
  }

  Future<void> _handleTaskAction(_TaskAction action) async {
    final provider = context.read<TaskProvider>();
    switch (action.type) {
      case _TaskActionType.delete:
        await provider.deleteTask(action.task);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => provider.restoreTask(action.task),
            ),
          ),
        );
        return;
      case _TaskActionType.complete:
        final generated = await provider.toggleDone(action.task, true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task marked done'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => provider.undoComplete(
                action.task,
                generatedRecurringTask: generated,
              ),
            ),
          ),
        );
        return;
      case _TaskActionType.uncomplete:
        await provider.toggleDone(action.task, false);
        return;
    }
  }
}

enum _TaskActionType { delete, complete, uncomplete }

class _TaskAction {
  const _TaskAction(this.type, this.task);

  final _TaskActionType type;
  final Task task;
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({super.key, required this.task, required this.onAction});

  final Task task;
  final Future<void> Function(_TaskAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final color = switch (task.priority) {
      2 => Colors.red,
      1 => Colors.orange,
      _ => Colors.green,
    };

    return Dismissible(
      key: ValueKey<String>('dismiss_${task.id}'),
      background: Container(color: Colors.red.withOpacity(0.2)),
      onDismissed: (_) => onAction(_TaskAction(_TaskActionType.delete, task)),
      child: CheckboxListTile(
        value: task.isDone,
        onChanged: (value) => onAction(
          _TaskAction(value == true ? _TaskActionType.complete : _TaskActionType.uncomplete, task),
        ),
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text([
              if (task.dueDate != null) DateFormat('yyyy-MM-dd').format(task.dueDate!),
              if (task.dueTime != null) task.dueTime!,
              if (task.isOverdue) 'OVERDUE',
              if (task.isRecurring) 'Repeat: ${task.recurrenceType.name}',
            ].join('  |  ')),
            if (task.subtasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Subtasks: ${task.subtasks.join(', ')}'),
              ),
          ],
        ),
        secondary: CircleAvatar(backgroundColor: color, radius: 6),
      ),
    );
  }
}
