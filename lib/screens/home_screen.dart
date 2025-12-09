import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:student_suite/models/tutorial_step.dart';
import '../providers/theme_provider.dart';
import 'planner_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/post_login_upgrade_dialog.dart';
import 'career_screen.dart';
import 'search_screen.dart';
import 'study_screen.dart';
import 'settings_screen.dart';
import '../widgets/profile_avatar.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/tutorial_provider.dart';
import '../widgets/app_bar_pomodoro_widget.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
// notes_screen is referenced directly elsewhere; helper removed to reduce unused warnings.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TutorialSupport<HomeScreen> {
  int _selectedIndex = 0;
  String? _lastShownBroadcastId;

  final GlobalKey<PlannerScreenState> _plannerKey =
      GlobalKey<PlannerScreenState>();

  late final List<Map<String, dynamic>> _screens;

  @override
  String get tutorialKey => 'home';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.dashboard_customize_outlined,
            title: 'Welcome to Your Dashboard!',
            description:
                'This is your central hub. You can navigate to all the tools from the bottom bar.'),
        TutorialStep(
            icon: Icons.search,
            title: 'Universal Search',
            description:
                'Use the search icon in the top right to instantly find any of your notes, flashcards, or AI lessons.'),
      ];

  @override
  void initState() {
    super.initState();

    _screens = [
      {
        'widget': PlannerScreen(
          key: _plannerKey,
          onCalendarToggle: _updateAppBarAndFAB,
        ),
        'title': 'Dashboard'
      },
      {'widget': const StudyScreen(), 'title': 'Study Tools'},
      {'widget': const CareerScreen(), 'title': 'Career Center'},
      {'widget': const SettingsScreen(), 'title': 'Settings'},
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShowPostLoginDialog();
      }
    });
  }

  // STATIC: Survives widget rebuilds (navigation race conditions)
  static bool _hasShownSessionPopup = false;

  // Inside _HomeScreenState...

  void _maybeShowPostLoginDialog() async {
    final subscription = context.read<SubscriptionProvider>();
    final auth = context.read<AuthProvider>();
    final tutorialProvider = context.read<TutorialProvider>();
    const dialogKey = 'post_login_upgrade_dialog';

    // 1. Loading Check
    if (auth.isLoading || subscription.isLoading) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // 2. TRIAL LOGIC (High Priority)
    if (!_hasShownSessionPopup && !kIsWeb) {
      final expiry = subscription.trialExpiryDate;
      final productId = subscription.currentProductId;

      // Case A: Active Trial, Ending Soon (<= 7 Days)
      if (subscription.isPro &&
          productId == 'referral_bonus' &&
          expiry != null) {
        final daysLeft = expiry.difference(DateTime.now()).inDays;

        if (daysLeft >= 0 && daysLeft <= 7) {
          _hasShownSessionPopup = true;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Don't lose your streak!"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your 30-day grant expires in $daysLeft days."),
                    const SizedBox(height: 10),
                    if (auth.isFounder)
                      const Text(
                        "You have a generic 50% OFF Founder status waiting (\$5.99/mo). This is a rare reward for our early supporters. Please don't let it slip away!",
                        style: TextStyle(fontSize: 14),
                      )
                    else
                      const Text(
                        "We hope you're loving the tools! AI tokens cost real money, and we are a small team relying on your support to keep this running.",
                        style: TextStyle(fontSize: 14),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Dismiss"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/account_settings');
                  },
                  child: const Text("Secure My Discount"),
                ),
              ],
            ),
          );
          return;
        }
      }

      // Case B: Just Expired (The "Guilt/Plead" Popup)
      if (!subscription.isPro && productId == 'referral_bonus') {
        _hasShownSessionPopup = true;
        showDialog(
          context: context,
          barrierDismissible: false, // Make them click a button
          builder: (ctx) => AlertDialog(
            title: const Text("Trial Expired"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "We hope you enjoyed your 30 free days! We loved having you.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Running powerful AI tools like the Resume Generator and Tutor costs us money for every token used. We gave you a month on us, but now we need your help to keep the lights on.",
                  ),
                  const SizedBox(height: 12),
                  // The "Invoice" Comparison
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow("Other Resume Apps", "~\$15/mo"),
                        _buildPriceRow("Other AI Tutors", "~\$20/mo"),
                        const Divider(),
                        _buildPriceRow("Student Suite",
                            auth.isFounder ? "\$5.99/mo" : "\$11.99/mo",
                            isBold: true, color: Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.isFounder
                        ? "You are a Founder. You get 50% off for life. Please, take the deal."
                        : "Save over \$20/mo by bundling with us.",
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Maybe Later"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/account_settings');
                },
                child: const Text("Support & Subscribe"),
              ),
            ],
          ),
        );
        return;
      }
    }

    // 3. Standard "New User" Upsell... (Existing code)
    if (!subscription.isPro &&
        !auth.isPro &&
        !tutorialProvider.hasSeen(dialogKey)) {
      if (mounted) {
        showPostLoginUpgradeDialog(context);
        tutorialProvider.markAsSeen(dialogKey);
      }
    }
  }

  // Helper widget for the price comparison
  Widget _buildPriceRow(String label, String price,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
          Text(price,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  void _updateAppBarAndFAB() {
    setState(() {
      debugPrint(
          'HomeScreen: _updateAppBarAndFAB called, HomeScreen rebuild triggered. (App bar should update)');
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final pomodoroProvider = context.watch<PomodoroProvider>();
    final auth = context.watch<AuthProvider>();
    final currentTheme = themeProvider.currentTheme;

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

    // This is the correct way to get the state of the child widget
    final PlannerScreenState? plannerState =
        _selectedIndex == 0 ? _plannerKey.currentState : null;

    final bool isCalendarView = plannerState?.isCalendarView ?? false;
    debugPrint(
        'HomeScreen: isCalendarView (from plannerState) = $isCalendarView. Selected Index: $_selectedIndex');

    final String appBarTitle = _selectedIndex == 0
        ? (plannerState?.currentTitle ?? _screens[0]['title'])
        : _screens[_selectedIndex]['title'];

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            appBarTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: currentTheme.navBarColor,
          elevation: 0,
          actions: [
            if (pomodoroProvider.isRunning &&
                !pomodoroProvider.isPomodoroScreenVisible)
              const AppBarPomodoroWidget(),
            if (_selectedIndex ==
                0) // Only show calendar toggle on Planner screen
              IconButton(
                key: const ValueKey('calendar_toggle_button'),
                icon: Icon(isCalendarView
                    ? Icons.dashboard_outlined
                    : Icons.calendar_today),
                tooltip: isCalendarView ? 'Show Dashboard' : 'Show Calendar',
                onPressed: () {
                  final currentPlannerState = _plannerKey.currentState;
                  debugPrint('HomeScreen: Calendar toggle button pressed.');
                  debugPrint(
                      'HomeScreen: _plannerKey.currentState is $currentPlannerState');
                  debugPrint(
                      'HomeScreen: isCalendarView before toggle: ${currentPlannerState?.isCalendarView}');

                  if (currentPlannerState != null) {
                    currentPlannerState.toggleCalendarView();
                    // Small delay to observe state after setState has a chance to propagate
                    Future.delayed(const Duration(milliseconds: 50), () {
                      debugPrint(
                          'HomeScreen: isCalendarView AFTER toggle (delayed): ${currentPlannerState.isCalendarView}');
                    });
                  } else {
                    debugPrint(
                        'HomeScreen ERROR: _plannerKey.currentState is NULL. Cannot toggle calendar.');
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: showTutorialDialog,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                  child: ProfileAvatar(
                    imageUrl: auth.profilePictureURL,
                    frameName: auth.profileFrame,
                    radius: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              // We must pass the actual widget instances here, initialized once.
              // The PlannerScreen's internal state manages its own visibility.
              children: _screens.map<Widget>((s) => s['widget']).toList(),
            ),
            // Broadcast overlay: show a dialog once per broadcast id when available
            Builder(builder: (context) {
              final auth = Provider.of<AuthProvider>(context);
              final broadcast = auth.latestBroadcast;
              if (broadcast != null) {
                final broadcastId =
                    (broadcast['id']?.toString() ?? 'latest_message');
                // Schedule showing the dialog after build
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  if (_lastShownBroadcastId == broadcastId) return;
                  _lastShownBroadcastId = broadcastId;
                  try {
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) {
                        final message =
                            broadcast['messageBody']?.toString() ?? '';
                        final buttonText = broadcast['buttonText']?.toString();
                        final buttonLink = broadcast['buttonLink']?.toString();
                        return AlertDialog(
                          title: const Text('Notice'),
                          content: SingleChildScrollView(
                            child: Text(message),
                          ),
                          actions: [
                            if (buttonText != null && buttonLink != null)
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  // Try to launch link if present; best-effort
                                  try {
                                    launchUrlString(buttonLink);
                                  } catch (_) {}
                                },
                                child: Text(buttonText),
                              ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Dismiss'),
                            ),
                          ],
                        );
                      },
                    );
                  } finally {
                    // Mark seen locally so it won't show again
                    try {
                      final authProv =
                          Provider.of<AuthProvider>(context, listen: false);
                      await authProv.markBroadcastSeen(broadcastId);
                    } catch (e) {
                      debugPrint(
                          'HomeScreen: failed to mark broadcast seen: $e');
                    }
                  }
                });
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
        floatingActionButton: _selectedIndex == 0
            ? FloatingActionButton(
                heroTag: 'planner_fab',
                onPressed: () {
                  final DateTime dateForDialog = (plannerState != null &&
                          plannerState.isCalendarView &&
                          plannerState.selectedDay != null)
                      ? plannerState.selectedDay!
                      : DateTime.now();
                  debugPrint(
                      'HomeScreen: FAB pressed. dateForDialog: $dateForDialog, plannerState: $plannerState');
                  // Call the showTaskDialog method directly on the PlannerScreenState
                  plannerState?.showTaskDialog(selectedDate: dateForDialog);
                },
                tooltip: 'Add Task',
                child: const Icon(Icons.add),
              )
            : null,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
              debugPrint(
                  'HomeScreen: Bottom nav index changed to $_selectedIndex');
              // If navigating away from Planner screen while calendar is open, close it
              if (index != 0 && (plannerState?.isCalendarView ?? false)) {
                debugPrint(
                    'HomeScreen: Navigating away from Planner. Calendar was open, closing it.');
                plannerState
                    ?.toggleCalendarView(); // This will also trigger _updateAppBarAndFAB
              }
            });
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.event_note), label: 'Planner'),
            BottomNavigationBarItem(
                icon: Icon(Icons.menu_book), label: 'Study'),
            BottomNavigationBarItem(
                icon: Icon(Icons.work), label: 'Career'), // FIXED
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
          backgroundColor: currentTheme.navBarColor,
          selectedItemColor: currentTheme.primaryAccent,
          unselectedItemColor:
              (currentTheme.navBarBrightness == Brightness.light
                      ? Colors.white
                      : Colors.black)
                  .withAlpha((0.7 * 255).round()),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
    );
  }

  // _buildNotesScreen was removed - NotesScreen is constructed directly where needed.
}
