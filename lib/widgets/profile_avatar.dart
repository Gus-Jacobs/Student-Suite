import 'package:flutter/material.dart';
import 'package:student_suite/models/profile_frame.dart';

/// A widget that displays a user's avatar within a selected profile frame.
/// It can render gradient frames, image frames, or no frame.
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? frameName;
  final double radius;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.frameName,
    this.radius = 50,
  });

  @override
  Widget build(BuildContext context) {
    final selectedFrame = getFrameByName(frameName);

    // The core avatar widget
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? NetworkImage(imageUrl!)
          : null,
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Icon(
              Icons.person,
              size: radius,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            )
          : null,
    );

    // If the frame is a gradient, wrap the avatar in a gradient border.
    if (selectedFrame.gradient != null) {
      return Container(
        width: (radius * 2) + 4, // Avatar size + border thickness
        height: (radius * 2) + 4,
        padding: const EdgeInsets.all(2), // This creates the ring thickness
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selectedFrame.gradient,
        ),
        child: avatar,
      );
    }

    // If the frame is an image, stack it on top of the avatar.
    if (selectedFrame.assetName != null &&
        selectedFrame.assetName!.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          Image.asset(
            'assets/img/frames/${selectedFrame.assetName}',
            width: radius * 2.5, // Frame is 25% larger than avatar diameter
            height: radius * 2.5,
            fit: BoxFit.contain,
          ),
        ],
      );
    }

    // If no frame is selected (or it's the 'None' frame), just return the avatar.
    return avatar;
  }
}
