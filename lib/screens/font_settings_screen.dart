import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter

import '../providers/theme_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/upgrade_dialog.dart';

class FontSettingsScreen extends StatefulWidget {
  const FontSettingsScreen({super.key});
  @override
  State<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

// The available fonts. "Roboto" is the default/free font.
const Map<String, String> fontOptions = {
  'Roboto': 'Default',
  'Lato': 'Light',
  'Montserrat': 'Modern',
  'Pacifico': 'Fun',
  'Metamorphous': 'Gothic',
};

class _FontSettingsScreenState extends State<FontSettingsScreen> {
  Future<void> _resetFontSettings() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setFontSizeScale(1.0);
    themeProvider.setFontFamily('Roboto');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Font settings restored to default.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final subscription = Provider.of<SubscriptionProvider>(context);
    final currentTheme = themeProvider.currentTheme;

    // Clamp font size to the slider's range to prevent crashes from invalid data.
    final double currentFontSizeScale =
        themeProvider.fontSizeScale.clamp(0.8, 1.5);

    // Ensure the current font family is a valid option to prevent crashes.
    final String currentFontFamily =
        fontOptions.containsKey(themeProvider.fontFamily)
            ? themeProvider.fontFamily
            : 'Roboto';

    BoxDecoration backgroundDecoration;
    if (currentTheme.imageAssetPath != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(currentTheme.imageAssetPath!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
              Colors.black.withAlpha((0.5 * 255).round()), BlendMode.darken),
        ),
      );
    } else {
      backgroundDecoration = BoxDecoration(gradient: currentTheme.gradient);
    }

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Font Settings'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildGlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Font Size',
                      style: Theme.of(context).textTheme.titleLarge),
                  Slider(
                    value: currentFontSizeScale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
                    label:
                        '${(currentFontSizeScale * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => themeProvider.setFontSizeScale(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Font Family',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                      value: currentFontFamily,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      underline:
                          const SizedBox(), // Removes the default underline
                      icon: Icon(Icons.arrow_drop_down,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((0.7 * 255).round())),
                      style: Theme.of(context).textTheme.bodyLarge,
                      items: fontOptions.entries
                          .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Row(
                                children: [
                                  Text(entry.value,
                                      style: TextStyle(fontFamily: entry.key)),
                                  if (entry.key != 'Roboto') ...[
                                    const Spacer(),
                                    const Icon(Icons.star,
                                        color: Colors.amber, size: 16)
                                  ]
                                ],
                              )))
                          .toList(),
                      onChanged: (String? newValue) async {
                        if (newValue != null) {
                          // Gate the feature for Pro users
                          if (newValue != 'Roboto' && !subscription.isPro) {
                            showUpgradeDialog(context);
                          } else {
                            themeProvider.setFontFamily(newValue);
                          }
                        }
                      }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetFontSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.withAlpha((0.7 * 255).round()),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                "Restore Defaults",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassColor = isDark
        ? Colors.white.withAlpha((0.1 * 255).round())
        : Colors.black.withAlpha((0.05 * 255).round());
    final glassBorderColor = isDark
        ? Colors.white.withAlpha((0.2 * 255).round())
        : Colors.black.withAlpha((0.1 * 255).round());
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: glassBorderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}
