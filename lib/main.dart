// main.dart

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/firebase_options.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/pomodoro_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/providers/tutorial_provider.dart';
import 'package:student_suite/screens/account_settings_screen.dart';
import 'package:student_suite/screens/ai_interviewer_screen.dart';
import 'package:student_suite/screens/ai_teacher_screen.dart';
import 'package:student_suite/screens/cover_letter_screen.dart';
import 'package:student_suite/screens/interview_tips_screen.dart';
import 'package:student_suite/screens/pomodoro_screen.dart';
import 'package:student_suite/screens/flashcard_screen.dart';
import 'package:student_suite/screens/font_settings_screen.dart';
import 'package:student_suite/screens/frame_settings_screen.dart';
import 'package:student_suite/screens/home_screen.dart';
import 'package:student_suite/screens/login_screen.dart';
import 'package:student_suite/screens/notes_screen.dart';
import 'package:student_suite/screens/onboarding_screen.dart';
import 'package:student_suite/screens/profile_screen.dart';
import 'package:student_suite/screens/resume_builder_screen.dart';
import 'package:student_suite/screens/signup_screen.dart';
import 'package:student_suite/screens/subject_manager_screen.dart';
import 'package:student_suite/screens/theme_settings_screen.dart';
import 'package:student_suite/widgets/themed_loading_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:student_suite/screens/saved_documents_screen.dart';

// Hive Model Imports
import 'package:student_suite/models/note.dart';
import 'package:student_suite/models/flashcard.dart';
import 'package:student_suite/models/flashcard_deck.dart';
import 'package:student_suite/models/hive_chat_message.dart';
import 'package:student_suite/models/ai_teacher_session.dart';
import 'package:student_suite/models/ai_interview_session.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/models/task.dart';
import 'package:student_suite/models/resume_data.dart';
import 'package:student_suite/models/contact_info_data.dart';
import 'package:student_suite/models/education_data.dart';
import 'package:student_suite/models/experience_data.dart';
import 'package:student_suite/models/certificate_data.dart';
import 'package:student_suite/models/saved_document.dart';

/// 🔑 Global navigatorKey so AuthProvider can force navigation resets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔑 Utility to clear all Hive boxes (call on logout/delete)
Future<void> clearAllHiveData() async {
  try {
    await Hive.deleteFromDisk();
    debugPrint('SUCCESS (Hive): All Hive data cleared.');
  } catch (e) {
    debugPrint('ERROR (Hive): Failed to clear Hive data: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firebase App Check is not always supported/required in web debug environments
  // and some flutterfire internals rely on platform JS hooks that aren't present
  // in certain dev/test setups. Activate App Check only on non-web platforms.
  // if (!kIsWeb) {
  //   await FirebaseAppCheck.instance.activate(
  //     // Use Debug provider ONLY in debug mode. Use Play Integrity in Release.
  //     androidProvider:
  //         kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  //     appleProvider: kDebugMode
  //         ? AppleProvider.debug
  //         : AppleProvider.appAttestWithDeviceCheckFallback,
  //   );
  // }

  if (kIsWeb) {
    await firebase_auth.FirebaseAuth.instance
        .setPersistence(firebase_auth.Persistence.LOCAL);
  }

  try {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NoteAdapter());
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FlashcardDeckAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(FlashcardAdapter());
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(HiveChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(AITeacherSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(AIInterviewSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(SubjectAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(ContactInfoDataAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(EducationDataAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ExperienceDataAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(CertificateDataAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(ResumeDataAdapter());
    }
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(SavedDocumentAdapter());
    }
  } catch (e) {
    debugPrint(
        'ERROR (Hive): An error occurred during Hive initialization: $e');
    debugPrint('Attempting to delete all Hive data and restart.');
    await clearAllHiveData();
  }

  final guestNotesBox = await Hive.openBox<Note>('guestNotes');
  final guestFlashcardDecksBox =
      await Hive.openBox<FlashcardDeck>('guestFlashcardDecks');
  final guestSubjectsBox = await Hive.openBox<Subject>('guestSubjects');
  final guestTasksBox = await Hive.openBox<Task>('guestTasks');
  final guestResumeDataBox = await Hive.openBox<ResumeData>('guestResumeData');
  final guestBroadcastSeenBox = await Hive.openBox('guestBroadcastSeen');

  final tutorialProvider = TutorialProvider();
  await tutorialProvider.init();

  final authProvider = AuthProvider();

  authProvider.setGuestNotesBox(guestNotesBox);
  authProvider.setGuestFlashcardDecksBox(guestFlashcardDecksBox);
  authProvider.setGuestSubjectsBox(guestSubjectsBox);
  authProvider.setGuestTasksBox(guestTasksBox);
  authProvider.setGuestResumeDataBox(guestResumeDataBox);
  authProvider.setGuestBroadcastSeenBox(guestBroadcastSeenBox);

  await authProvider.init();

  runApp(MyApp(
    tutorialProvider: tutorialProvider,
    authProvider: authProvider,
  ));
}

class MyApp extends StatelessWidget {
  final TutorialProvider tutorialProvider;
  final AuthProvider authProvider;
  const MyApp({
    super.key,
    required this.tutorialProvider,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        // SubscriptionProvider now depends on AuthProvider
        ChangeNotifierProxyProvider<AuthProvider, SubscriptionProvider>(
          create: (context) => SubscriptionProvider(),
          update: (context, auth, previous) {
            final subProv = previous ?? SubscriptionProvider();
            try {
              subProv.update(auth.user);
            } catch (_) {}
            return subProv;
          },
        ),
        // ThemeProvider now depends on BOTH AuthProvider and SubscriptionProvider
        ChangeNotifierProxyProvider2<AuthProvider, SubscriptionProvider,
            ThemeProvider>(
          create: (_) => ThemeProvider(),
          update: (context, auth, subscription, previous) {
            final themeProv = previous ?? ThemeProvider();
            try {
              // Pass both providers to the update function
              themeProv.updateForUser(auth, subscription);
            } catch (_) {}
            return themeProv;
          },
        ),
        ChangeNotifierProvider(create: (_) => PomodoroProvider()),
        ChangeNotifierProvider.value(value: tutorialProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return MaterialApp(
                navigatorKey: navigatorKey, // ✅ global key
                title: 'Student Suite',
                theme: themeProvider.lightThemeData,
                darkTheme: themeProvider.darkThemeData,
                themeMode: themeProvider.themeMode,
                // Defensive: child can be null in some engine configurations
                // (especially during app startup on some platforms). Avoid using
                // `child!` which throws and produces a white/blank screen.
                builder: (context, child) {
                  return ThemedLoadingOverlay(
                    isLoading: auth.isLoading,
                    // Use a safe fallback if child is null to prevent crashes.
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: const AuthGate(),
                routes: {
                  '/home': (context) => const HomeScreen(),
                  '/login': (context) => const LoginScreen(),
                  '/signup': (context) => const SignupScreen(),
                  '/profile': (context) => const ProfileScreen(),
                  '/account_settings': (context) =>
                      const AccountSettingsScreen(),
                  '/theme_settings': (context) => const ThemeSettingsScreen(),
                  '/font_settings': (context) => const FontSettingsScreen(),
                  '/frame_settings': (context) => const FrameSettingsScreen(),
                  '/notes': (context) => const NotesScreen(),
                  '/flashcards': (context) => const FlashcardScreen(),
                  '/ai_teacher': (context) => const AITeacherScreen(),
                  '/ai_interviewer': (context) => const AIInterviewerScreen(),
                  '/resume': (context) => const ResumeBuilderScreen(),
                  '/cover_letter': (context) => const CoverLetterScreen(),
                  '/subjects': (context) => const SubjectManagerScreen(),
                  '/pomodoro': (context) => const PomodoroScreen(),
                  '/interview_tips': (context) => const InterviewTipsScreen(),
                  '/saved_documents': (context) =>
                      const SavedDocumentsScreen(), // <--- ADD THIS
                },
              );
            },
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final themeProvider = Provider.of<ThemeProvider>(
            context,
            listen: false,
          );
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: themeProvider.currentTheme.gradient,
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // If the auth stream produced an error, surface a friendly error UI
        // instead of letting the app fail silently and show a white screen.
        if (snapshot.hasError) {
          final themeProvider = Provider.of<ThemeProvider>(
            context,
            listen: false,
          );
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: themeProvider.currentTheme.gradient,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text(
                        'An error occurred while loading authentication.'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        // Attempt a soft recovery: sign out which resets state and
                        // lets the app reinitialize.
                        try {
                          await firebase_auth.FirebaseAuth.instance.signOut();
                        } catch (_) {}
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // --- THIS IS THE FIX ---
          // User is logged in, but we MUST wait for their profile to load
          // before showing the main app.
          return FutureBuilder(
            future: Provider.of<AuthProvider>(context, listen: false)
                .profileLoadFuture,
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                // Use the same loading screen as the AuthGate
                final themeProvider = Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                );
                return Scaffold(
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: themeProvider.currentTheme.gradient,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              // The profile is loaded. It is NOW safe to show the app.
              return const HomeScreen();
            },
          );
        } else {
          return const OnboardingScreen();
        }
      },
    );
  }
}
