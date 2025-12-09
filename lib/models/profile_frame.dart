import 'package:flutter/material.dart';

/// Represents a profile frame, which can be either a gradient or an image.
class ProfileFrame {
  final String name;
  final String? assetName; // For image frames, e.g., 'gold_gradient.png'
  final Gradient? gradient; // For gradient frames
  final bool isPro;

  const ProfileFrame({
    required this.name,
    this.assetName,
    this.gradient,
    this.isPro = false,
  }) : assert(assetName != null || gradient != null || name == 'None',
            'Frame must have an asset or a gradient, or be the "None" frame.');
}

/// A central list of all available profile frames in the app.
final List<ProfileFrame> profileFrames = [
  // --- Special "None" Frame ---
  const ProfileFrame(name: 'None', isPro: false),

  // --- Gradient Frames ---
  const ProfileFrame(
    name: 'Sunset',
    gradient: SweepGradient(
      colors: [Colors.deepOrange, Colors.amber, Colors.pink, Colors.deepOrange],
    ),
    isPro: true,
  ),
  const ProfileFrame(
    name: 'Ocean',
    gradient: SweepGradient(
      colors: [Colors.blue, Colors.cyan, Colors.teal, Colors.blue],
    ),
    isPro: true,
  ),
  const ProfileFrame(
    name: 'Forest',
    gradient: SweepGradient(
      colors: [Colors.green, Colors.lightGreen, Colors.brown, Colors.green],
    ),
    isPro: true,
  ),
  const ProfileFrame(
    name: 'Amethyst',
    gradient: SweepGradient(
      colors: [
        Colors.purple,
        Colors.deepPurple,
        Colors.pinkAccent,
        Colors.purple
      ],
    ),
    isPro: true,
  ),

  // --- Image Frames ---
  const ProfileFrame(name: 'Meta', assetName: 'meta.png', isPro: true),
  const ProfileFrame(name: 'Flowers', assetName: 'flowers.png', isPro: true),
  const ProfileFrame(name: 'Tech', assetName: 'tech.png', isPro: true),
  const ProfileFrame(name: 'Student', assetName: 'student.png', isPro: true),
];

/// Helper function to find a frame by its unique name.
ProfileFrame getFrameByName(String? name) {
  if (name == null) return profileFrames.first; // Default to 'None'
  return profileFrames.firstWhere((f) => f.name == name,
      orElse: () => profileFrames.first);
}
