import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter
import '../providers/theme_provider.dart';

class ThemedLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const ThemedLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          // This modal barrier prevents interaction with the UI behind it.
          const ModalBarrier(dismissible: false, color: Colors.black26),
        if (isLoading)
          // The actual loading UI
          _buildLoadingUI(context),
      ],
    );
  }

  Widget _buildLoadingUI(BuildContext context) {
    // Defensive: ThemeProvider may not be available during very early
    // frames (or during some test harnesses). Use Theme.of(context) as a
    // fallback to ensure the loading UI always renders.
    Gradient? gradient;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      gradient = themeProvider.currentTheme.gradient;
    } catch (_) {
      gradient = null;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient ??
              LinearGradient(colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).scaffoldBackgroundColor
              ]),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}
