import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';

class GlassInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const GlassInfoTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final onSurfaceColor = theme.colorScheme.onSurface;

    // Define theme-aware colors for the glass effect.
    final glassColor = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.1)
        : const Color.fromRGBO(0, 0, 0, 0.05);
    final glassBorderColor = isDark
        ? const Color.fromRGBO(255, 255, 255, 0.2)
        : const Color.fromRGBO(0, 0, 0, 0.1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: currentTheme.glassGradient,
              color: currentTheme.glassGradient == null ? glassColor : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glassBorderColor),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, color: onSurfaceColor, size: 28),
              title: Text(title,
                  style: TextStyle(
                      color: onSurfaceColor.withAlpha((0.7 * 255).toInt()),
                      fontSize: 14)),
              subtitle: Text(subtitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: onSurfaceColor)),
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
  }
}
