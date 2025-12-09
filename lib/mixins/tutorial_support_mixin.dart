import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/tutorial_step.dart';
import 'package:student_suite/providers/tutorial_provider.dart';
import 'package:student_suite/widgets/tutorial_dialog.dart';

/// A mixin to add standardized tutorial support to a StatefulWidget's State.
///
/// It handles showing a tutorial dialog automatically on the first visit to a screen
/// and provides a method to show it again on demand.
mixin TutorialSupport<T extends StatefulWidget> on State<T> {
  /// The unique key for this screen's tutorial (e.g., 'home', 'notes').
  String get tutorialKey;

  /// The list of steps for this screen's tutorial.
  List<TutorialStep> get tutorialSteps;

  /// Checks if the tutorial has been seen and shows it if it hasn't.
  /// This should typically be called in `initState` within a
  /// `WidgetsBinding.instance.addPostFrameCallback`.
  void showTutorialIfNeeded() {
    // Ensure the context is still mounted before using it.
    if (!mounted) return;
    final tutorialProvider = context.read<TutorialProvider>();
    if (!tutorialProvider.hasSeen(tutorialKey)) {
      showTutorialDialog();
    }
  }

  /// Shows the tutorial dialog.
  /// This can be called from a help button or any other user action.
  void showTutorialDialog() {
    // Ensure the context is still mounted before using it.
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) =>
          TutorialDialog(tutorialKey: tutorialKey, steps: tutorialSteps),
    );
  }
}
