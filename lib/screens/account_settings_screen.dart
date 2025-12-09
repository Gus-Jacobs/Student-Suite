// lib/screens/account_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_action_tile.dart';
import '../widgets/glass_info_tile.dart';
import '../providers/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../utils/error_utils.dart';
import '../widgets/promotional_card.dart';
import 'package:student_suite/main.dart'; // For navigatorKey
// ...existing imports...

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _showRestoreOption = false;
  ConfettiController? _confettiController;
  bool _celebrated = false;
  bool _isDeleting = false;

  // Track previous isPro so we only celebrate on a real transition
  bool _previousIsPro = false;
  bool _previousIsProInitialized = false;

  late AnimationController _popupAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _popupAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnimation = CurvedAnimation(
        parent: _popupAnimationController, curve: Curves.easeOutBack);
    final subProv = Provider.of<SubscriptionProvider>(context, listen: false);
    subProv.addListener(_checkSubscriptionChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);

      subscriptionProvider.clearPurchaseError();
      _showRestoreOption = false;

      // Load subscription state and kick off IAP product fetch
      subscriptionProvider.loadSubscriptionStatus(auth.user);
      subscriptionProvider.initializePurchaseFlow();
    });
  }

  @override
  void dispose() {
    try {
      // Safely attempt to remove listener
      final subProv = Provider.of<SubscriptionProvider>(context, listen: false);
      subProv.removeListener(_checkSubscriptionChange);
    } catch (e) {
      // Ignore provider errors during disposal
    }
    _confettiController?.dispose();
    _popupAnimationController.dispose();
    super.dispose();
  }

  void _checkSubscriptionChange() {
    if (!mounted || _isDeleting) return;
    final sub = Provider.of<SubscriptionProvider>(context, listen: false);

    // Trigger only if moving from free -> pro
    if (sub.isPro && !_previousIsPro) {
      _triggerCelebration();
    }
    _previousIsPro = sub.isPro;
  }

  void _triggerCelebration() {
    // Only once, and only while mounted
    if (_celebrated) return;
    _celebrated = true;

    if (!mounted) return;
    // Use addPostFrameCallback to avoid ancestor lookups during unstable frames
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Show snackbar safely
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Purchase Successful!"),
          backgroundColor: Colors.green,
        ),
      );

      _showThankYouPopup();
      _confettiController?.play();
    });
  }

  void _showThankYouPopup() {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ThankYouDialog",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium,
                      color: Colors.amber, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    "Thank You!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You are now a Pro user.\nEnjoy your premium features!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (mounted) Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Got it!"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(scale: _scaleAnimation, child: child);
      },
    );

    _popupAnimationController.forward(from: 0);
  }

  void _showRestoreDialog(SubscriptionProvider subscription) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restore Purchases"),
        content: const Text(
          "We couldn’t validate your receipt. "
          "Would you like to try restoring your purchases?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await subscription.restorePurchases();
            },
            child: const Text("Restore"),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTile(
      SubscriptionProvider subscription, AuthProvider auth) {
    if (subscription.isLoading) {
      return const GlassActionTile(
        icon: Icons.hourglass_empty,
        title: 'Loading...',
        onTap: null,
      );
    }

    if (subscription.isPro) {
      // Show Manage button — no celebration here
      return GlassActionTile(
        icon: Icons.manage_accounts,
        title: 'Manage Subscription',
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            if (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.android) {
              await subscription.manageIAPPurchase();
            } else {
              await subscription.manageStripeSubscription();
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text("Manage error: $e")),
              );
            }
          }
        },
      );
    }

    final hasProducts = subscription.products.isNotEmpty;
    // Web uses Stripe; mobile uses native products. Keep canBuy true on web
    final canBuy = kIsWeb
        ? true
        : (defaultTargetPlatform == TargetPlatform.iOS
            ? subscription.canBuySubscription
            : hasProducts);

    return GlassActionTile(
      icon: Icons.upgrade,
      title: 'Upgrade to Pro',
      onTap: canBuy
          ? () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                // Attempt the purchase logic
                final initiated =
                    await subscription.buySubscription(auth.isFounder);

                // CHECK: Did we succeed immediately (e.g., Debug or fast native return)?
                if (subscription.isPro) {
                  _triggerCelebration();
                  return;
                }

                if (!initiated) {
                  // If web, attempt direct checkout session as a fallback
                  if (kIsWeb) {
                    try {
                      if (subscription.purchaseError != null &&
                          subscription.purchaseError!.toLowerCase().contains(
                              'payment system temporarily unavailable')) {
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Stripe is currently unavailable. Please try again later or contact support.')),
                        );
                        return;
                      }

                      await subscription.launchCheckoutSession(
                          'price_1P3zY1J2xQ3zY1J2xQ3zY1J3');
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Checkout failed: $e')),
                      );
                    }
                    return;
                  }

                  // Surface error for mobile/native
                  if (mounted && subscription.purchaseError != null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            "Purchase failed: ${subscription.purchaseError!}"),
                        action: SnackBarAction(
                          label: 'Restore',
                          onPressed: () => subscription.restorePurchases(),
                        ),
                      ),
                    );
                  }

                  if (subscription.purchaseError != null &&
                      (subscription.purchaseError!.contains("21002") ||
                          subscription.purchaseError!.contains("21007") ||
                          subscription.purchaseError!.contains("21010"))) {
                    setState(() {
                      _showRestoreOption = true;
                    });
                    _showRestoreDialog(subscription);
                  }
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final subscription = Provider.of<SubscriptionProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
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

    return Stack(
      children: [
        Container(decoration: backgroundDecoration),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Account'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Consumer<SubscriptionProvider>(
            builder: (context, sub, child) {
              // 🔹 Purchase error handling
              // 🔹 Purchase error handling (always immediate)
              if (sub.purchaseError != null ||
                  sub.lastCheckoutServerError != null) {
                final errorMsg =
                    sub.lastCheckoutServerError ?? sub.purchaseError!;
                final messenger = ScaffoldMessenger.of(context);
                final docPath = sub.lastCheckoutDocPath;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text("Payment Error: $errorMsg"),
                        duration: const Duration(seconds: 8),
                        action: SnackBarAction(
                          label: 'Retry',
                          onPressed: () async {
                            try {
                              final auth = context.read<AuthProvider>();
                              await sub.buySubscription(auth.isFounder);
                            } catch (e) {
                              messenger.showSnackBar(
                                  SnackBar(content: Text('Retry failed: $e')));
                            }
                          },
                        ),
                      ),
                    );

                    // If there's a server-side checkout doc, show a second SnackBar
                    // with a Contact action and a quick debug copy-to-clipboard.
                    if (docPath != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Checkout session created: $docPath'),
                          duration: const Duration(seconds: 6),
                          action: SnackBarAction(
                            label: 'Copy Path',
                            onPressed: () {
                              // Copy the doc path to clipboard for easy logging
                              // (import is added above).
                              Clipboard.setData(ClipboardData(text: docPath));
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Doc path copied')));
                            },
                          ),
                        ),
                      );
                    }

                    sub.clearPurchaseError();
                  }
                });
              }

              // 🔹 Celebration logic
              if (!_previousIsProInitialized) {
                _previousIsPro = sub.isPro;
                _previousIsProInitialized = true;
              } else {
                if (sub.isPro && !_previousIsPro && !_isDeleting) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_isDeleting) _triggerCelebration();
                  });
                }
                _previousIsPro = sub.isPro;
              }

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  GlassInfoTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: auth.user?.email ?? 'Not logged in',
                  ),
                  GlassActionTile(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Referral Code',
                    // The backend expects the first 8 chars of the UID (see AuthProvider.signUp)
                    subtitle: auth.user != null
                        ? auth.user!.uid.substring(0, 8).toUpperCase()
                        : '...',
                    onTap: () {
                      if (auth.user != null) {
                        final code =
                            auth.user!.uid.substring(0, 8).toUpperCase();
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied referral code: $code'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),

                  // 🔹 Only show promotions if user has them
                  if (auth.activePromotions.isNotEmpty)
                    PromotionsCard(
                      onRedeem: (promoType) {
                        if (promoType == 'referral_bonus') {
                          Navigator.pushNamed(context, '/checkout', arguments: {
                            'promo': 'referral_bonus',
                          });
                        } else if (promoType == 'founder_discount') {
                          Navigator.pushNamed(context, '/checkout', arguments: {
                            'promo': 'founder_discount',
                          });
                        }
                      },
                    ),

                  GlassActionTile(
                    icon: Icons.alternate_email,
                    title: 'Change Email',
                    onTap: () => _showUpdateDialog(
                      context: context,
                      title: 'Change Email',
                      newFieldLabel: 'New Email',
                      onUpdate: auth.updateUserEmail,
                    ),
                  ),
                  GlassActionTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    onTap: () => _showUpdateDialog(
                      context: context,
                      title: 'Change Password',
                      newFieldLabel: 'New Password',
                      onUpdate: auth.updateUserPassword,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 48),

                  GlassInfoTile(
                    icon: Icons.workspace_premium,
                    title: 'Subscription',
                    subtitle: subscription.isPro ? 'Pro User' : 'Free User',
                  ),
                  // --- TRIAL COUNTDOWN TILE ---
// Only show if: Pro, on Referral Grant, and has valid date
                  if (subscription.isPro &&
                      subscription.currentProductId == 'referral_bonus' &&
                      subscription.trialExpiryDate != null)
                    Builder(builder: (context) {
                      final daysLeft = subscription.trialExpiryDate!
                          .difference(DateTime.now())
                          .inDays;
                      // Don't show negative days (expired)
                      if (daysLeft < 0) return const SizedBox.shrink();

                      // Color logic: Red if urgent (<3 days), Orange (<7), Green otherwise
                      Color statusColor = Colors.greenAccent;
                      if (daysLeft <= 3)
                        statusColor = Colors.redAccent;
                      else if (daysLeft <= 7) statusColor = Colors.orangeAccent;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: ListTile(
                          leading:
                              Icon(Icons.timer_outlined, color: statusColor),
                          title: Text(
                            "$daysLeft Days Left",
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            "Trial Grant Active",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }),
// ----------------------------
                  _buildSubscriptionTile(subscription, auth),

                  if (_showRestoreOption)
                    GlassActionTile(
                      icon: Icons.restore,
                      title: 'Restore Purchases',
                      onTap: subscription.restorePurchases,
                    ),

                  const Divider(color: Colors.white24, height: 48),
                  _buildDeleteAccountButton(auth, subscription),
                  _buildLogoutButton(auth),
                ],
              );
            },
          ),
        ),
        if (_confettiController != null)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController!,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.green, Colors.blue, Colors.purple],
            ),
          ),
      ],
    );
  }

  // --- unchanged dialogs/buttons ---

  void _showUpdateDialog({
    required BuildContext context,
    required String title,
    required String newFieldLabel,
    required Function(String, String) onUpdate,
  }) {
    final TextEditingController newFieldController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isUpdating = false;
            String? errorMessage;

            Future<void> handleUpdate() async {
              setState(() {
                isUpdating = true;
                errorMessage = null;
              });
              // Capture navigator and messenger tied to the dialog's context
              final NavigatorState navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(ctx);
              try {
                await onUpdate(
                  newFieldController.text.trim(),
                  passwordController.text.trim(),
                );
                // Use captured navigator/messenger instead of dialog builder context
                navigator.pop();
                if (title == 'Change Email') {
                  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                  messenger.showSnackBar(
                    const SnackBar(
                        content: Text('Email updated. Please log in again.')),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('$title updated successfully.')),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                setState(() {
                  isUpdating = false;
                  errorMessage = ErrorUtils.getFriendlyMessage(e);
                });
              }
            }

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newFieldController,
                    decoration: InputDecoration(labelText: newFieldLabel),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration:
                        const InputDecoration(labelText: 'Current Password'),
                    obscureText: true,
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isUpdating ? null : handleUpdate,
                  child: isUpdating
                      ? const CircularProgressIndicator()
                      : Text('Change $newFieldLabel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeleteAccountButton(
      AuthProvider auth, SubscriptionProvider subscription) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Semantics(
        label: 'Delete Account Permanently',
        button: true,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.delete_forever_outlined),
          // Visible text must match reviewer requirement
          label: const Text('Delete Account Permanently'),
          onPressed: () =>
              _showDeleteAccountDialog(context, auth, subscription),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            // Ensure minimum tappable area (44x44 points). On large
            // devices this guarantees easy target size.
            minimumSize: const Size(44, 44),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Semantics(
        label: 'Log Out',
        button: true,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
          // ... inside _buildLogoutButton ...
          onPressed: () async {
            // 1. Capture what we need
            final navigator = Navigator.of(context);
            final authProv = context.read<AuthProvider>();
            final themeProv = context.read<ThemeProvider>();
            final subProv = context.read<SubscriptionProvider>();

            try {
              // 2. NAVIGATE FIRST.
              // Get off this screen immediately so we aren't trying to render
              // user data while the user is being deleted from memory.
              navigator.popUntil((route) => route.isFirst);

              // 3. Then clean up
              await subProv.cancelStreams();
              await subProv.resetProStatus();
              await themeProv.resetToDefault();
              await authProv.logout();
            } catch (e) {
              debugPrint('Logout error: $e');
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blueGrey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: const Size(44, 44),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    AuthProvider auth,
    SubscriptionProvider subscription,
  ) {
    final TextEditingController passwordController = TextEditingController();
    final parentContext = context;

    // ... (Keep your warning message logic) ...
    final bool isPro = subscription.isPro;
    final bool isStripe = subscription.isStripeSubscription;
    final bool isIAP = subscription.isIAPSubscription;
    String warningMessage = "";
    if (isPro) {
      // ... (Your existing warning logic) ...
      if (isStripe) {
        warningMessage =
            "⚠️ Stripe subscription active. Deleting account attempts to cancel it, but manual check recommended.";
      } else if (isIAP) {
        warningMessage =
            "⚠️ IAP Subscription active. You MUST cancel this in the App Store manually.";
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isDeleting = false;
            final ValueNotifier<bool> passwordObscure =
                ValueNotifier<bool>(true);
            String? errorMessage;

            Future<void> handleDelete() async {
              // 1. Update UI locally to show loading spinner inside the button
              setState(() {
                isDeleting = true;
                errorMessage = null;
              });

              try {
                // 2. Perform Delete with "Pre-Delete Action"
                // We pass a callback to navigate away immediately when the password is verified,
                // BUT BEFORE the account is actually destroyed in Firebase.
                await auth.deleteAccount(passwordController.text.trim(),
                    onPreDeleteAction: () {
                  // CRITICAL: Pop everything and go to login immediately.
                  // This prevents the "Red Screen" because we leave before the user becomes null.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                });

                // 3. Success (Code execution usually stops here as we've navigated away)
              } catch (e) {
                // 4. Failure (Wrong password, etc.)
                // We are still on the screen, so we show the error.
                if (context.mounted) {
                  setState(() {
                    isDeleting = false;
                    errorMessage = ErrorUtils.getFriendlyMessage(e);
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Delete Account Permanently'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'This action is irreversible and will remove your data.'),
                    const SizedBox(height: 16),
                    if (warningMessage.isNotEmpty)
                      Text(warningMessage,
                          style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    // ... (Keep password field UI) ...
                    ValueListenableBuilder<bool>(
                      valueListenable: passwordObscure,
                      builder: (context, isObscure, _) {
                        return TextField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(isObscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => passwordObscure.value =
                                  !passwordObscure.value,
                            ),
                          ),
                          obscureText: isObscure,
                        );
                      },
                    ),
                    if (errorMessage != null)
                      Text(errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: handleDelete,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
