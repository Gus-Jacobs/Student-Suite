import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';

class GlassActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const GlassActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
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

    // Determine if the tile should be in a loading state.
    // We check if onTap is null, which is how the parent widget signals a loading state.
    final bool isLoading = onTap == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: currentTheme.glassGradient,
              color: currentTheme.glassGradient == null ? glassColor : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glassBorderColor),
            ),
            child: Material(
              color: Colors.transparent,
              // Accessibility: Ensure minimum tappable area (44x44pt) by
              // constraining the ListTile to a reasonable minimum height.
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: ListTile(
                  // Increase horizontal/vertical padding to improve touch targets
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  mouseCursor: isLoading
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  onTap: onTap,
                  leading: isLoading
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor ?? onSurfaceColor,
                          ),
                        )
                      : Icon(icon,
                          color: iconColor ?? onSurfaceColor, size: 28),
                  title: Text(title,
                      style: TextStyle(
                          color: titleColor ?? onSurfaceColor,
                          fontWeight: FontWeight.bold)),
                  subtitle: subtitle != null
                      ? Text(subtitle!,
                          style: TextStyle(
                              color: onSurfaceColor
                                  .withAlpha((0.7 * 255).round())))
                      : null,
                  trailing: isLoading
                      ? null
                      : Icon(Icons.arrow_forward_ios,
                          color: onSurfaceColor.withAlpha((0.7 * 255).round()),
                          size: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
