import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
// removed unused imports

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isPasswordObscured = true;
  // Keep a reference to the AuthProvider so we don't call context.read()
  // from dispose() which can cause "deactivated widget's ancestor" errors.
  late AuthProvider _authProvider;
  bool _authListenerAttached = false;

  @override
  void initState() {
    super.initState();
    // It's good practice to clear any lingering snackbars from previous screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   // Capture the AuthProvider once and attach our listener safely. We
  //   // avoid calling Provider.of/removeListener in dispose using BuildContext
  //   // because the element tree may already be deactivated at that point.
  //   _authProvider = Provider.of<AuthProvider>(context, listen: false);
  //   if (!_authListenerAttached) {
  //     try {
  //       _authProvider.addListener(_onAuthStateChanged);
  //       _authListenerAttached = true;
  //     } catch (e) {
  //       // If attaching the listener fails for any reason, swallow the error
  //       // and continue; this avoids hard crashes during teardown.
  //       debugPrint('LoginScreen: failed to attach auth listener: $e');
  //     }
  //   }
  // }

  // void _onAuthStateChanged() {
  //   final auth = context.read<AuthProvider>();
  //   // If we are on this screen and the user is now logged in, pop back to the AuthGate.
  //   if (auth.user != null && mounted) {
  //     // This ensures that once login is complete, this screen is removed
  //     // from the navigation stack, revealing the HomeScreen managed by AuthGate.
  //     Navigator.of(context).popUntil((route) => route.isFirst);
  //   }
  // }

  Future<void> _handleLogin(BuildContext context) async {
    // Dismiss the keyboard to prevent UI overflow when the loading indicator appears.
    FocusScope.of(context).unfocus();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Capture values that access the BuildContext before any awaits so we
    // don't use the context after an async gap (fixes lints and races).
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final email = _email.text.trim();
    final password = _password.text.trim();

    final bool success = await auth.login(email, password);

    if (success) {
      // Navigation is handled by the AuthGate/listener. AuthProvider handles box opening.
      if (mounted) {
        // Success! Clear the login screen so the Home Screen (underneath) is revealed.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      // If login fails, show an error. The loading state is automatically
      // handled by the AuthProvider.
      final errorMsg = auth.error ?? 'An unknown error occurred during login.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _handlePasswordReset(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _email.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter your email to reset password.')),
      );
      return;
    }

    // Capture messenger before async work so we can safely show results
    // after awaiting without using BuildContext across an async gap.
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.resetPassword(email);

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Password reset email sent. Check your inbox.')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed to send reset email.')),
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
                      items: ['Login Issue', 'Bug Report', 'General Inquiry']
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

      // Show a loading indicator
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
          'email': user?.email ??
              _email.text.trim(), // Use entered email if not logged in
          'displayName': auth.displayName.isNotEmpty ? auth.displayName : 'N/A',
          'category': category,
          'message': messageController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'version': await _getAppVersion(),
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        });

        // Pop loading indicator and then the feedback form
        navigator.pop(); // Pop loading indicator
        navigator.pop(); // Pop feedback dialog

        messenger.showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      } catch (e) {
        // Pop loading indicator
        navigator.pop();
        messenger.showSnackBar(
            SnackBar(content: Text('Failed to send feedback: $e')));
      }
    }
  }

  Future<String> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = Theme.of(context);
    // Ensure status bar icons are light to contrast with the dark gradient
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints viewportConstraints) {
          BoxDecoration backgroundDecoration;
          if (themeProvider.currentTheme.imageAssetPath != null) {
            backgroundDecoration = BoxDecoration(
              image: DecorationImage(
                image: AssetImage(themeProvider.currentTheme.imageAssetPath!),
                fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(
                  Color.fromRGBO(0, 0, 0, 0.5),
                  BlendMode.darken,
                ),
              ),
            );
          } else {
            backgroundDecoration =
                BoxDecoration(gradient: themeProvider.currentTheme.gradient);
          }
          return Container(
            decoration: backgroundDecoration,
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
                          const SizedBox(height: 40),
                          Text(
                            'Welcome Back,',
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
                            'Log in to continue',
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
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _handleLogin(context),
                              child: const Text('Login'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _handlePasswordReset(context),
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _showFeedbackDialog(context, 'Login Issue'),
                            child: const Text('Contact Support'),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account?",
                                  style: TextStyle(color: Colors.white70)),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pushNamed(context, '/signup'),
                                child: const Text('Sign Up'),
                              ),
                            ],
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
