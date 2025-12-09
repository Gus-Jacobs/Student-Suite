import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../providers/theme_provider.dart';
import 'package:student_suite/main.dart'; // Required for navigatorKey

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  bool _isPasswordObscured = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  // void _onAuthStateChanged() {
  //   final auth = context.read<AuthProvider>();
  //   // If we are on this screen and the user is now logged in, pop back to the AuthGate.
  //   if (auth.user != null && mounted) {
  //     // This ensures that once signup is complete, this screen is removed
  //     // from the navigation stack, revealing the HomeScreen managed by AuthGate.
  //     Navigator.of(context).popUntil((route) => route.isFirst);
  //   }
  // }

  Future<void> _handleSignup(BuildContext context) async {
    FocusScope.of(context).unfocus();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _email.text.trim();
    final password = _password.text.trim();
    final referralCode = _referralCodeController.text.trim();

    // Define navigator HERE so it is available in try AND catch blocks
    final navigator = Navigator.of(context);

    if (email.isEmpty || password.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Signup Failed'),
          content: const Text('Email and password cannot be empty.'),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Show Blocking Spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
    );

    try {
      final bool success = await auth.signUp(
        email,
        password,
        referralCode: referralCode,
      );

      // Close Spinner
      navigator.pop();

      if (success) {
        // Nuclear Option: Use Global Key to force reset to Home
        //navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
        navigator.popUntil((route) => route.isFirst);
      } else {
        // Failure Logic
        String errorMsg = auth.error ?? 'Signup failed.';
        if (auth.error?.contains('email-already-in-use') ?? false) {
          errorMsg = 'This email is already registered. Try logging in.';
        } else if (auth.error?.contains('weak-password') ?? false) {
          errorMsg = 'Password should be at least 6 characters.';
        }

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Signup Failed'),
              content: Text(errorMsg),
              actions: [
                TextButton(
                    onPressed: () => navigator.pop(), child: const Text('OK')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Safety: Close spinner if open
      if (navigator.canPop()) navigator.pop();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text('System error: $e'),
            actions: [
              TextButton(
                  onPressed: () => navigator.pop(), child: const Text('OK'))
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _showFeedbackDialog(BuildContext context, String initialCategory) {
    final formKey = GlobalKey<FormState>();
    final messageController = TextEditingController();
    String category = initialCategory; // 'Issue' or 'Feedback'

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          // Use StatefulBuilder to manage dialog state
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Contact Support'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: category,
                      items: ['Signup Issue', 'Bug Report', 'General Inquiry']
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            category = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Your Message',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message.';
                        }
                        return null;
                      },
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
                  onPressed: () => _submitFeedback(
                      ctx, formKey, category, messageController),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitFeedback(BuildContext context, GlobalKey<FormState> formKey,
      String category, TextEditingController messageController) async {
    if (formKey.currentState?.validate() ?? false) {
      // It's good practice to get a reference to the Navigator and
      // ScaffoldMessenger before an async call if the widget's context might
      // become invalid.
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      final auth = context.read<AuthProvider>();
      final user = auth.user;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
      );

      try {
        await FirebaseFirestore.instance.collection('feedback').add({
          'userId': user?.uid ?? 'anonymous',
          'email': user?.email ?? _email.text.trim(),
          'displayName': auth.displayName.isNotEmpty ? auth.displayName : 'N/A',
          'category': category,
          'message': messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'version': '1.0.0+1',
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        });

        navigator.pop(); // Pop loading indicator
        navigator.pop(); // Pop feedback dialog

        messenger.showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      } catch (e) {
        navigator.pop();
        messenger.showSnackBar(
            SnackBar(content: Text('Failed to send feedback: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentTheme = themeProvider.currentTheme;
    final theme = Theme.of(context);
    // Ensure status bar icons are light to contrast with the dark gradient
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          return Container(
            decoration: currentTheme.imageAssetPath != null
                ? BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(currentTheme.imageAssetPath!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          Colors.black.withAlpha((0.5 * 255).round()),
                          BlendMode.darken),
                    ),
                  )
                : BoxDecoration(gradient: currentTheme.gradient),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom back button to replace AppBar
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Create Account,',
                            style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  const Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.black38,
                                    offset: Offset(2.0, 2.0),
                                  ),
                                ]),
                          ),
                          Text(
                            'Sign up to get started',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: Colors.white70, shadows: [
                              const Shadow(
                                blurRadius: 8.0,
                                color: Colors.black26,
                                offset: Offset(1.0, 1.0),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 48),
                          TextField(
                            controller: _email,
                            decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined)),
                            keyboardType: TextInputType.emailAddress,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _password,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordObscured
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordObscured = !_isPasswordObscured;
                                  });
                                },
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            obscureText: _isPasswordObscured,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _referralCodeController,
                            decoration: const InputDecoration(
                                labelText: 'Referral Code (Optional)',
                                prefixIcon: Icon(Icons.card_giftcard)),
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleSignup(context),
                              child: const Text('Sign Up'),
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  _showFeedbackDialog(context, 'Signup Issue'),
                              child: const Text('Contact Support'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
