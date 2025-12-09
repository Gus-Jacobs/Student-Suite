import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/models/tutorial_step.dart';
import '../providers/theme_provider.dart';
import '../providers/pomodoro_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:math';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TutorialSupport<PomodoroScreen> {
  late ConfettiController _confettiController;
  StreamSubscription? _sessionCompleteListener;
  PomodoroProvider? _pomodoroProvider;

  @override
  String get tutorialKey => 'pomodoro';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.timer_outlined,
            title: 'Focus with Pomodoro',
            description:
                'Use the Pomodoro Technique to break down work into focused intervals, separated by short breaks.'),
        TutorialStep(
            icon: Icons.play_circle_outline,
            title: 'Control Your Session',
            description:
                "Press 'Start' to begin a session. You can pause or reset it at any time using the controls."),
        TutorialStep(
            icon: Icons.settings_outlined,
            title: 'Customize Duration',
            description:
                'Tap the settings icon in the top right to change the work duration to fit your study style.'),
        TutorialStep(
            icon: Icons.track_changes_outlined,
            title: 'Track Anywhere',
            description:
                'When a timer is running, a mini version will appear in the top bar so you can see your time left from any screen.'),
      ];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionCompleteListener =
          context.read<PomodoroProvider>().onSessionComplete.listen((_) {
        _confettiController.play();
        _showCompletionDialog();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pomodoroProvider = Provider.of<PomodoroProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _sessionCompleteListener?.cancel();
    // FIX: Use the property setter, not a method
    if (_pomodoroProvider != null) {
      _pomodoroProvider!.isPomodoroScreenVisible = false;
    }
    super.dispose();
  }

  void _showSettingsDialog() {
    final pomodoro = Provider.of<PomodoroProvider>(context, listen: false);
    final tempDuration =
        ValueNotifier<double>(pomodoro.workDurationInSeconds.toDouble() / 60);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Work Duration'),
        content: ValueListenableBuilder<double>(
          valueListenable: tempDuration,
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${value.round()} minutes'),
                Slider(
                  value: value,
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '${value.round()}',
                  onChanged: (newValue) {
                    tempDuration.value = newValue;
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              pomodoro.setWorkDuration(tempDuration.value.round());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    const List<String> quotes = [
      "The secret of getting ahead is getting started.",
      "The only way to do great work is to love what you do.",
      "Believe you can and you're halfway there.",
      "Well done is better than well said.",
      "Success is the sum of small efforts, repeated day in and day out.",
      "Focus on being productive instead of busy.",
      "The future depends on what you do today.",
    ];
    final quote = quotes[Random().nextInt(quotes.length)];
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Session Complete!'),
          content: Text('"$quote"'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nice!'))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final pomodoro = context.watch<PomodoroProvider>();
    final currentTheme = themeProvider.currentTheme;
    final theme = Theme.of(context);

    BoxDecoration backgroundDecoration;
    if (currentTheme.imageAssetPath != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(currentTheme.imageAssetPath!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withAlpha((0.5 * 255).round()),
            BlendMode.darken,
          ),
        ),
      );
    } else {
      backgroundDecoration = BoxDecoration(gradient: currentTheme.gradient);
    }
    return VisibilityDetector(
      key: const Key('pomodoro-screen-visibility'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        // Set visibility based on whether the screen is mostly visible.
        context.read<PomodoroProvider>().isPomodoroScreenVisible =
            visiblePercentage > 50;
      },
      child: Container(
        decoration: backgroundDecoration,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Pomodoro Timer'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help',
                onPressed: showTutorialDialog,
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: _showSettingsDialog,
                tooltip: 'Settings',
              )
            ],
          ),
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 250,
                            height: 250,
                            child: CircularProgressIndicator(
                              value: pomodoro.workDurationInSeconds > 0
                                  ? pomodoro.secondsLeft /
                                      pomodoro.workDurationInSeconds
                                  : 1.0,
                              strokeWidth: 12,
                              backgroundColor:
                                  Colors.white.withAlpha((0.2 * 255).round()),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary),
                            ),
                          ),
                          Text(pomodoro.timeString,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(pomodoro.isRunning
                              ? Icons.pause
                              : Icons.play_arrow),
                          onPressed: pomodoro.isRunning
                              ? pomodoro.pause
                              : pomodoro.start,
                          label: Text(pomodoro.isRunning ? 'Pause' : 'Start'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: pomodoro.reset,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Sessions completed: ${pomodoro.sessions}',
                        style: const TextStyle(color: Colors.white70)),
                    const Divider(height: 32, color: Colors.white30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Sessions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        TextButton(
                          onPressed: pomodoro.history.isNotEmpty
                              ? pomodoro.clearHistory
                              : null,
                          child: Text(
                            'Clear History',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      flex: 1,
                      child: pomodoro.history.isEmpty
                          ? const Center(
                              child: Text('No history yet.',
                                  style: TextStyle(color: Colors.white70)))
                          : ListView.builder(
                              itemCount: pomodoro.history.length,
                              itemBuilder: (context, i) {
                                final dt = pomodoro.history[i];
                                return ListTile(
                                  leading: const Icon(Icons.history,
                                      color: Colors.white70),
                                  title: Text(
                                      DateFormat.yMMMd().add_jm().format(dt),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
