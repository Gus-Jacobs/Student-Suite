import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // For ImageFilter
import '../providers/auth_provider.dart';
import '../models/profile_frame.dart';
import '../providers/subscription_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/upgrade_dialog.dart';

enum FrameType { gradient, image }

class FrameSettingsScreen extends StatefulWidget {
  const FrameSettingsScreen({super.key});

  @override
  State<FrameSettingsScreen> createState() => _FrameSettingsScreenState();
}

class _FrameSettingsScreenState extends State<FrameSettingsScreen> {
  FrameType _selectedFrameType = FrameType.gradient;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;
    final List<ProfileFrame> framesToShow;

    if (_selectedFrameType == FrameType.gradient) {
      // Show 'None' and all gradient frames
      framesToShow = profileFrames
          .where((f) => f.gradient != null || f.name == 'None')
          .toList();
    } else {
      // Show 'None' and all image frames
      framesToShow = profileFrames
          .where((f) => f.assetName != null || f.name == 'None')
          .toList();
    }
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
          title: const Text('Profile Frames'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SegmentedButton<FrameType>(
                segments: const [
                  ButtonSegment(
                      value: FrameType.gradient, label: Text('Gradients')),
                  ButtonSegment(value: FrameType.image, label: Text('Images')),
                ],
                selected: {_selectedFrameType},
                onSelectionChanged: (newSelection) {
                  setState(() => _selectedFrameType = newSelection.first);
                },
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.8,
                ),
                itemCount: framesToShow.length,
                itemBuilder: (context, index) {
                  final frame = framesToShow[index];
                  return _FramePreviewCard(frame: frame);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FramePreviewCard extends StatelessWidget {
  final ProfileFrame frame;
  const _FramePreviewCard({
    required this.frame,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final subscription = context.watch<SubscriptionProvider>();
    final isSelected = auth.profileFrame == frame.name;

    return MouseRegion(
      // <--- Add MouseRegion here
      cursor: SystemMouseCursors.click, // <--- Set cursor here
      child: GestureDetector(
        onTap: () {
          if (frame.isPro && !subscription.isPro) {
            showUpgradeDialog(context);
          } else {
            auth.updateUserPreferences({'profileFrame': frame.name});
          }
        },
        child: Card(
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isSelected
                ? const BorderSide(color: Colors.white, width: 3)
                : BorderSide(
                    color: Colors.white.withAlpha((0.3 * 255).round())),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      // Glassmorphism background
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: Container(
                            color: Colors.black.withAlpha((0.1 * 255).round())),
                      ),
                      // Avatar Preview
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ProfileAvatar(
                            imageUrl: auth.profilePictureURL,
                            frameName: frame.name,
                            radius: 45),
                      ),
                      if (isSelected)
                        Container(
                          color: Colors.black.withAlpha((0.4 * 255).round()),
                          child: const Icon(Icons.check_circle,
                              color: Colors.white, size: 36),
                        ),
                      if (frame.isPro && !isSelected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  Colors.amber.withAlpha((0.8 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.black.withAlpha((0.4 * 255).round()),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text(
                      frame.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
