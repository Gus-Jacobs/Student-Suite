import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pomodoro_provider.dart';

class AppBarPomodoroWidget extends StatelessWidget {
  const AppBarPomodoroWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PomodoroProvider>(
      builder: (context, pomodoro, child) {
        // Only show if running or visible
        if (!pomodoro.isRunning && !pomodoro.isPomodoroScreenVisible) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            ),
            onPressed: () {
              Navigator.of(context).pushNamed('/pomodoro');
            },
            icon: Stack(
              alignment: Alignment.center,
              children: [
                // Animated circle for status
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    value: pomodoro.workDurationInSeconds > 0
                        ? pomodoro.secondsLeft / pomodoro.workDurationInSeconds
                        : 1.0,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey.withAlpha((0.2 * 255).round()),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pomodoro.isRunning
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ),
                const Icon(Icons.timer_outlined, size: 18),
              ],
            ),
            label: Text(
              pomodoro.timeString,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}
