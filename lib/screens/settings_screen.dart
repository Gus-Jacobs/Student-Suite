import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:student_suite/widgets/glass_action_tile.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for launching URLs
import 'dart:io' show Platform; // Only import Platform for non-web

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Account Settings - show different tiles based on login state
        if (auth.user == null)
          // Show this if user is not logged in
          GlassActionTile(
            icon: Icons.login,
            title: 'Login',
            subtitle: 'Log in or create an account',
            onTap: () {
              // Navigate to login screen
              Navigator.pushNamed(context, '/login');
            },
          )
        else
          // Show this if user is logged in
          GlassActionTile(
            icon: Icons.verified_user_outlined,
            title: 'Account',
            subtitle: 'Manage subscription and security',
            onTap: () => Navigator.pushNamed(context, '/account_settings'),
          ),
        GlassActionTile(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Manage your personal information',
          onTap: () => Navigator.pushNamed(context, '/profile'),
        ),
        GlassActionTile(
          icon: Icons.palette_outlined,
          title: 'Theme & Colors',
          subtitle: 'Change the look and feel of the app',
          onTap: () => Navigator.pushNamed(context, '/theme_settings'),
        ),
        GlassActionTile(
          icon: Icons.font_download_outlined,
          title: 'Font Settings',
          subtitle: 'Adjust text size and style',
          onTap: () => Navigator.pushNamed(context, '/font_settings'),
        ),
        GlassActionTile(
          icon: Icons.library_books_outlined,
          title: 'AI Context Subjects',
          subtitle: 'Provide context for AI tools',
          onTap: () => Navigator.pushNamed(context, '/subjects'),
        ),
        const Divider(height: 24, color: Colors.white24),
        GlassActionTile(
          icon: Icons.email_outlined,
          title: 'Contact Support',
          subtitle: 'Get help with any issues',
          onTap: () => _showSupportDialog(context),
        ),
        GlassActionTile(
          icon: Icons.lightbulb_outline,
          title: 'Send Feedback',
          subtitle: 'Report an issue or suggest a feature',
          onTap: () => _showFeedbackDialog(context),
        ),
        const Divider(color: Colors.white24, height: 48),
        GlassActionTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'View our data usage and privacy details',
          onTap: () async {
            // Launch external URL for Privacy Policy
            final uri = Uri.parse('https://pegumax.com/policy');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open privacy policy link.'),
                  ),
                );
              }
            }
          },
        ),
        FutureBuilder<String>(
          future: _getAppVersion(),
          builder: (context, snapshot) {
            final version = snapshot.data ?? '...';
            return GlassActionTile(
              icon: Icons.info_outline,
              title: 'App Version',
              subtitle: 'v$version',
              onTap: () {}, // Set onTap to null to make it non-clickable
            );
          },
        ),
        // Logout button shown only if user is logged in
        if (auth.user != null) ...[
          const SizedBox(height: 24),
          _buildLogoutButton(context),
        ],
      ],
    );
  }

  // Moved _buildLogoutButton inside the class
  // Replace the _buildLogoutButton method:
  Widget _buildLogoutButton(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout_outlined),
        label: const Text('Log Out'),
        // ... inside _buildLogoutButton ...
        onPressed: () async {
          // 1. Capture
          final navigator = Navigator.of(context);
          final auth = Provider.of<AuthProvider>(context, listen: false);

          // 2. Navigate First (Prevent White Screen)
          navigator.popUntil((route) => route.isFirst);

          // 3. Logout
          try {
            await auth.logout();
          } catch (e) {
            debugPrint("Logout error: $e");
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 5,
          shadowColor: const Color.fromRGBO(0, 0, 0, 0.5),
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    String? selectedCategory;
    final List<String> feedbackCategories = [
      'General Feedback',
      'Feature Request',
      'Report an Issue',
      'Praise',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Send Feedback'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedCategory,
                      items: feedbackCategories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedCategory = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      keyboardType: TextInputType.multiline,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Your Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _sendEmail(
                    context,
                    'Feedback',
                    messageController,
                    selectedCategory,
                  ),
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSupportDialog(BuildContext context) {
    final TextEditingController messageController = TextEditingController();
    String? selectedCategory;
    final List<String> supportCategories = [
      'Login/Account Issue',
      'Subscription Problem',
      'Technical Error',
      'Question',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Contact Support'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Topic',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedCategory,
                      items: supportCategories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedCategory = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a topic' : null,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      keyboardType: TextInputType.multiline,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Your Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _sendEmail(
                    context,
                    'Support Request',
                    messageController,
                    selectedCategory,
                  ),
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Replace the _sendEmail method:
  Future<void> _sendEmail(
    BuildContext context,
    String type,
    TextEditingController messageController,
    String? category,
  ) async {
    if (messageController.text.isEmpty || category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a category and enter a message.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // FIX: Capture references BEFORE the async call
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('sendAppEmail');

      await callable.call({
        'userId': user?.uid ?? 'anonymous',
        'email': user?.email ?? 'anonymous',
        'type': type,
        'category': category,
        'message': messageController.text.trim(),
        'version': await _getAppVersion(),
        'platform': kIsWeb
            ? 'web'
            : (Platform.isIOS
                ? 'iOS'
                : (Platform.isAndroid ? 'Android' : Platform.operatingSystem)),
      });

      // FIX: Use captured navigator/messenger
      navigator.pop(); // Pop loading
      navigator.pop(); // Pop dialog

      messenger.showSnackBar(
        const SnackBar(content: Text('Thank you! Your message has been sent.')),
      );
    } catch (e) {
      // FIX: Use captured navigator/messenger in catch
      navigator.pop(); // Pop loading
      messenger
          .showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  Future<String> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
