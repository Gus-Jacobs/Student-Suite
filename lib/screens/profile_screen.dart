import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/glass_action_tile.dart';
import '../widgets/upgrade_dialog.dart';
// For ImageFilter

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _displayNameController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the current display name from the provider.
    // Using context.read here is safe because it's a one-time read in initState.
    final auth = context.read<AuthProvider>();
    _displayNameController = TextEditingController(text: auth.displayName);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final newName = _displayNameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty.')),
      );
      return;
    }

    await auth.updateDisplayName(newName);

    if (mounted && auth.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );
    } else if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${auth.error}')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final auth = context.read<AuthProvider>();
    final subscription = context.read<SubscriptionProvider>();

    if (!subscription.isPro) {
      showUpgradeDialog(context);
      return;
    }

    await auth.updateProfilePicture();

    if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${auth.error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to rebuild the widget when AuthProvider changes.
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final themeProvider = context.watch<ThemeProvider>();
        final currentTheme = themeProvider.currentTheme;

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

        return Container(
          decoration: backgroundDecoration,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Profile'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: auth.user == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    children: [
                      Center(
                        child: MouseRegion(
                          // <--- ADDED MouseRegion here
                          cursor: SystemMouseCursors
                              .click, // <--- Set the cursor here
                          child: GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                ProfileAvatar(
                                  imageUrl: auth.profilePictureURL,
                                  frameName: auth.profileFrame,
                                  radius: 50,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withAlpha((0.6 * 255).round()),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          auth.user?.email ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _displayNameController,
                        decoration:
                            const InputDecoration(labelText: 'Display Name'),
                        onSubmitted: (_) => _saveProfile(),
                      ),
                      if (auth.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            auth.error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (auth.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          onPressed: _saveProfile,
                          label: const Text('Save Profile'),
                        ),
                      const SizedBox(height: 24),
                      GlassActionTile(
                        icon: Icons.photo_filter_outlined,
                        title: 'Customize Profile Frame',
                        onTap: () =>
                            Navigator.pushNamed(context, '/frame_settings'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
