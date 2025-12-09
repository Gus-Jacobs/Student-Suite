import 'package:flutter/material.dart';
import 'package:student_suite/models/task.dart';
import 'package:student_suite/screens/task_dialog.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Helper for 'explode' effect (simple scale and fade)
class _ExplodeEffect extends StatefulWidget {
  const _ExplodeEffect({required this.color});
  final Color color;

  @override
  _ExplodeEffectState createState() => _ExplodeEffectState();
}

class _ExplodeEffectState extends State<_ExplodeEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation =
        Tween<double>(begin: 0.1, end: 1.5).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _opacityAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 30, // Small explosion visual
              height: 30,
              decoration: BoxDecoration(
                color: widget.color
                    .withAlpha((_opacityAnimation.value * 0.7 * 255).round()),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class TaskManagerDialog extends StatefulWidget {
  final DateTime selectedDate;
  final List<Task> tasksForDay;
  final Function(Task) onAddTask;
  final Function(Task) onUpdateTask;
  final Function(Task) onDeleteTask;

  const TaskManagerDialog({
    super.key,
    required this.selectedDate,
    required this.tasksForDay,
    required this.onAddTask,
    required this.onUpdateTask,
    required this.onDeleteTask,
  });

  @override
  State<TaskManagerDialog> createState() => _TaskManagerDialogState();
}

class _TaskManagerDialogState extends State<TaskManagerDialog>
    with SingleTickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _animatedListKey =
      GlobalKey<AnimatedListState>();
  late List<Task> _localTasksForDay;

  // Animation controller for task completion bounce effect
  late AnimationController _taskCompleteAnimationController;
  // Map to store individual task animation controllers if needed, or rely on global state update
  // For simplicity, we'll trigger a full item rebuild in AnimatedList on update for now.

  @override
  void initState() {
    super.initState();
    _localTasksForDay = List.from(widget.tasksForDay);
    _sortLocalTasks();

    _taskCompleteAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _taskCompleteAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TaskManagerDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This is crucial: If tasks are changed *outside* this dialog (e.g., from dashboard)
    // and then the dialog is reopened or kept open, its internal list needs to sync.
    // However, since we close the dialog on add/edit, this is mostly for external changes
    // or if the dialog isn't always dismissed.
    // For a simple dialog, we might simplify this, but good to have a basic sync.
    if (!listEquals(oldWidget.tasksForDay, widget.tasksForDay)) {
      // Rebuilding AnimatedList completely is simpler but less performant for large lists.
      // For this task management, it's likely fine.
      // A more complex solution would calculate diffs and use specific insert/remove/update.
      setState(() {
        _localTasksForDay = List.from(widget.tasksForDay);
        _sortLocalTasks();
      });
      // A full AnimatedList refresh would involve recreating the key, which is disruptive.
      // We rely on item rebuilds, but if state is truly out of sync, a better mechanism
      // for AnimatedList would be needed (e.g., re-initializing AnimatedList items based on diffs).
    }
  }

  bool listEquals(List<Task> list1, List<Task> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id ||
          list1[i].isCompleted != list2[i].isCompleted) {
        return false;
      }
    }
    return true;
  }

  void _sortLocalTasks() {
    _localTasksForDay.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      return a.date.compareTo(b.date);
    });
  }

  // PASTE THIS into task_manager_dialog.dart

  Future<void> _showAddTaskDialog({Task? taskToEdit}) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => TaskDialog(
        task: taskToEdit,
        selectedDate: widget.selectedDate,
      ),
    );

    if (result != null) {
      if (taskToEdit == null) {
        // --- This is a NEW task ---
        widget.onAddTask(result); // This calls planner_screen's _addTask
        setState(() {
          _localTasksForDay.add(result);
          _sortLocalTasks();
          final actualIndex = _localTasksForDay.indexOf(result);
          if (actualIndex != -1) {
            _animatedListKey.currentState?.insertItem(actualIndex,
                duration: const Duration(milliseconds: 500));
          }
        });
      } else {
        // --- THIS IS THE FIX ---
        // This is an EDITED task.
        // The 'result' IS the original task object, now modified.
        await result.save(); // Save the changes to Hive
        widget.onUpdateTask(result); // This calls planner_screen's _updateTask
        setState(() {
          // Find the old task in the list and replace it
          final int oldIndex =
              _localTasksForDay.indexWhere((t) => t.id == result.id);
          if (oldIndex != -1) {
            _localTasksForDay[oldIndex] = result;
            _sortLocalTasks(); // Re-sort just in case
          }
        });
      }
      // We DO NOT pop the TaskManagerDialog. This was a bug.
      // The user should be able to add/edit multiple tasks.
    }
  }

  void _deleteTask(Task task) {
    final int index = _localTasksForDay.indexOf(task);
    if (index != -1) {
      final removedItem = _localTasksForDay.removeAt(index);
      _animatedListKey.currentState?.removeItem(
        index,
        (context, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            child: _buildTaskListItem(removedItem,
                Provider.of<ThemeProvider>(context, listen: false).currentTheme,
                showExplodeEffect: true), // Pass true to show explode
          ),
        ),
        duration: const Duration(milliseconds: 400),
      );
      widget.onDeleteTask(task); // Propagate delete to PlannerScreenState
    }
  }

  void _toggleTaskCompletion(Task task) {
    setState(() {
      task.isCompleted = !task.isCompleted;
      _sortLocalTasks(); // Re-sort to move completed tasks to bottom
      widget.onUpdateTask(task); // Notify parent (PlannerScreen)

      // Trigger bounce animation for the completed task
      _taskCompleteAnimationController.forward(from: 0.0).then((_) {
        _taskCompleteAnimationController.reverse();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context)
          .cardColor
          .withAlpha((0.9 * 255).round()), // Using standard cardColor
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tasks for ${DateFormat.yMMMd().format(widget.selectedDate)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 15),
            _localTasksForDay.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      'No tasks for this day. Click "Add Task" to create one!',
                      style: TextStyle(
                          color: colorScheme.onSurface
                              .withAlpha((0.7 * 255).round())),
                      textAlign: TextAlign.center,
                    ),
                  )
                : Flexible(
                    child: AnimatedList(
                      key: _animatedListKey,
                      shrinkWrap: true,
                      initialItemCount: _localTasksForDay.length,
                      itemBuilder: (context, index, animation) {
                        final task = _localTasksForDay[index];
                        return SizeTransition(
                          // "Fall down" effect
                          sizeFactor: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: _buildTaskListItem(task, currentTheme),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () => _showAddTaskDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTheme.primaryAccent,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                    color:
                        colorScheme.onSurface.withAlpha((0.7 * 255).round())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListItem(Task task, AppTheme currentTheme,
      {bool showExplodeEffect = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      // For task completion bounce/scale
      animation: _taskCompleteAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: task.isCompleted
              ? (1.0 + (_taskCompleteAnimationController.value * 0.05))
              : 1.0, // Subtle bounce
          child: Card(
            color: currentTheme.navBarColor.withAlpha((0.8 * 255).round()),
            margin: const EdgeInsets.only(bottom: 8), // Adjusted margin
            child: Stack(
              children: [
                ListTile(
                  leading: Checkbox(
                    value: task.isCompleted,
                    onChanged: (val) {
                      if (val != null) {
                        _toggleTaskCompletion(task);
                      }
                    },
                    activeColor: currentTheme.primaryAccent,
                    checkColor: colorScheme.onPrimary,
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                      decorationThickness: 2,
                      decorationColor:
                          colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                  subtitle: task.description.isNotEmpty
                      ? Text(
                          task.description,
                          style: TextStyle(
                              color: colorScheme.onSurface
                                  .withAlpha((0.7 * 255).round())),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            Icon(Icons.edit, color: currentTheme.primaryAccent),
                        onPressed: () => _showAddTaskDialog(taskToEdit: task),
                      ),
                      IconButton(
                        // Explicit Delete Button
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () => _deleteTask(task),
                      ),
                    ],
                  ),
                  onTap: () => _showAddTaskDialog(
                      taskToEdit: task), // Still allow tapping to edit
                ),
                if (showExplodeEffect) // Show explode only when explicitly requested (on delete)
                  const Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ExplodeEffect(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
