import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:student_suite/models/resume_data.dart';
import 'package:student_suite/models/ai_interview_session.dart';
import 'package:student_suite/models/ai_teacher_session.dart';
import 'package:student_suite/models/flashcard_deck.dart';
import 'package:student_suite/models/note.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/models/task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:student_suite/models/hive_chat_message.dart';
import 'package:student_suite/utils/error_utils.dart';
import 'package:student_suite/models/flashcard.dart'; // <-- ADD THIS LINE
import 'package:student_suite/main.dart'; // Access navigatorKey
import 'package:student_suite/models/saved_document.dart';

class AuthProvider extends ChangeNotifier {
  // Firebase User object
  User? user;
  // --- Promotions ---
  List<Map<String, dynamic>> _activePromotions = [];
  List<Map<String, dynamic>> get activePromotions => _activePromotions;

  // State Flags
  bool _isLoading = true; // Use private for internal state
  String? error;
  bool _isInitialized = false; // New flag to prevent re-initialization

  // User Profile Data (from Firestore)
  String _displayName = '';
  String? profilePictureURL;
  String? stripeRole;
  bool isFounder = false;
  String? themeName;
  String? themeMode;
  double? fontSizeScale;
  String? profileFrame;
  String? fontFamily;

  // User-specific Hive boxes (private, assigned when user logs in)
  Box<Note>? _notesBox;
  Box<FlashcardDeck>? _flashcardDecksBox;
  Box<AITeacherSession>? _aiTeacherSessionsBox;
  Box<AIInterviewSession>? _aiInterviewSessionsBox;
  Box<Subject>? _subjectsBox;
  Box<Task>? _tasksBox;
  Box<ResumeData>? _resumeDataBox;
  Box<HiveChatMessage>? _chatMessagesBox;
  Box<Flashcard>? _flashcardsBox; // <-- ADD THIS LINE
  Box<SavedDocument>? _savedDocumentsBox;

  // Global/Guest Hive boxes (passed from main.dart)
  late Box<Note> _guestNotesBox;
  late Box<FlashcardDeck> _guestFlashcardDecksBox;
  late Box<Subject> _guestSubjectsBox;
  late Box<Task> _guestTasksBox;
  late Box<ResumeData> _guestResumeDataBox;
  Box<dynamic>? _guestBroadcastSeenBox;

  // Public getters
  bool get isLoading => _isLoading; // Public getter for _isLoading

  // Getters for Hive Boxes with defensive checks
  Box<Note> get notesBox {
    if (user != null) {
      assert(
        _notesBox != null && _notesBox!.isOpen,
        'User is logged in but _notesBox is null or closed. Check _openUserSpecificBoxes.',
      );
      return _notesBox!;
    } else {
      assert(_guestNotesBox.isOpen, '_guestNotesBox is not open.');
      return _guestNotesBox;
    }
  }

  Box<FlashcardDeck> get flashcardDecksBox {
    if (user != null) {
      assert(
        _flashcardDecksBox != null && _flashcardDecksBox!.isOpen,
        'User is logged in but _flashcardDecksBox is null or closed.',
      );
      return _flashcardDecksBox!;
    }
    assert(
      _guestFlashcardDecksBox.isOpen,
      '_guestFlashcardDecksBox is not open.',
    );
    // Corrected typo: Changed _guestFlashcardDeances to _guestFlashcardDecksBox
    return _guestFlashcardDecksBox;
  }

  Box<AITeacherSession> get aiTeacherSessionsBox {
    if (user != null) {
      assert(
        _aiTeacherSessionsBox != null && _aiTeacherSessionsBox!.isOpen,
        'User is logged in but _aiTeacherSessionsBox is null or closed.',
      );
      return _aiTeacherSessionsBox!;
    }
    throw StateError(
      "AITeacherSessionBox is only available for logged-in users.",
    );
  }

  Box<AIInterviewSession> get aiInterviewSessionsBox {
    if (user != null) {
      assert(
        _aiInterviewSessionsBox != null && _aiInterviewSessionsBox!.isOpen,
        'User is logged in but _aiInterviewSessionsBox is null or closed.',
      );
      return _aiInterviewSessionsBox!;
    }
    throw StateError(
      "AIInterviewSessionBox is only available for logged-in users.",
    );
  }

  Box<Subject> get subjectsBox {
    if (user != null) {
      assert(
        _subjectsBox != null && _subjectsBox!.isOpen,
        'User is logged in but _subjectsBox is null or closed.',
      );
      return _subjectsBox!;
    }
    assert(_guestSubjectsBox.isOpen, '_guestSubjectsBox is not open.');
    return _guestSubjectsBox;
  }

  Box<Task> get tasksBox {
    if (user != null) {
      assert(
        _tasksBox != null && _tasksBox!.isOpen,
        'User is logged in but _tasksBox is null or closed.',
      );
      return _tasksBox!;
    }
    assert(_guestTasksBox.isOpen, '_guestTasksBox is not open.');
    return _guestTasksBox;
  }

  Box<ResumeData> get resumeDataBox {
    if (user != null) {
      assert(
        _resumeDataBox != null && _resumeDataBox!.isOpen,
        'User is logged in but _resumeDataBox is null or closed.',
      );
      return _resumeDataBox!;
    }
    assert(_guestResumeDataBox.isOpen, '_guestResumeDataBox is not open.');
    return _guestResumeDataBox;
  }

  Box<HiveChatMessage> get chatMessagesBox {
    if (user != null) {
      assert(
        _chatMessagesBox != null && _chatMessagesBox!.isOpen,
        'User is logged in but _chatMessagesBox is null or closed.',
      );
      return _chatMessagesBox!;
    }
    throw StateError("ChatMessagesBox is only available for logged-in users.");
  }

  // ADD THIS GETTER:
  Box<Flashcard> get flashcardsBox {
    if (user != null) {
      assert(
        _flashcardsBox != null && _flashcardsBox!.isOpen,
        'User is logged in but _flashcardsBox is null or closed.',
      );
      return _flashcardsBox!;
    }
    throw StateError("FlashcardsBox is only available for logged-in users.");
  }

  Box<SavedDocument> get savedDocumentsBox {
    // Same safety logic as your other boxes
    if (user != null) {
      assert(_savedDocumentsBox != null && _savedDocumentsBox!.isOpen);
      return _savedDocumentsBox!;
    }
    throw StateError("Saved Documents only available for logged in users.");
  }

  // Setters for guest boxes (called from main.dart during app startup)
  void setGuestNotesBox(Box<Note> box) => _guestNotesBox = box;
  void setGuestFlashcardDecksBox(Box<FlashcardDeck> box) =>
      _guestFlashcardDecksBox = box;
  void setGuestSubjectsBox(Box<Subject> box) => _guestSubjectsBox = box;
  void setGuestTasksBox(Box<Task> box) => _guestTasksBox = box;
  void setGuestResumeDataBox(Box<ResumeData> box) => _guestResumeDataBox = box;
  void setGuestBroadcastSeenBox(Box<dynamic> box) =>
      _guestBroadcastSeenBox = box;

  /// Mark a broadcast as seen for the current user (or guest).
  Future<void> markBroadcastSeen(String broadcastId) async {
    final key = user != null ? 'lastSeen_${user!.uid}' : 'lastSeen_guest';
    try {
      final box = _guestBroadcastSeenBox;
      if (box != null && box.isOpen) {
        await box.put(key, broadcastId);
      }
    } catch (e) {
      debugPrint('AUTH: markBroadcastSeen failed: $e');
    }
  }

  // Internal state
  final _secureStorage = const FlutterSecureStorage();
  StreamSubscription<DocumentSnapshot>? _userProfileSubscription;
  StreamSubscription<DocumentSnapshot>? _broadcastSubscription;
  StreamSubscription<User?>? _authStateChangesSubscription;
  Completer<void>? _profileLoadCompleter;

  // Track the currently loaded user's UID to prevent redundant operations
  String? _currentLoadedUserId;

  Map<String, dynamic>? _latestBroadcast;
  Map<String, dynamic>? get latestBroadcast => _latestBroadcast;

  // NEW: Store custom claim 'isPro' status
  bool _isProCustomClaim = false;
  Future<void>? get profileLoadFuture => _profileLoadCompleter?.future;

  // --- Getters ---
  String get displayName => _displayName;
  // Updated isPro getter to use _isProCustomClaim
  bool get isPro => (stripeRole == 'pro') || (_isProCustomClaim);

  // --- Initialization ---
  AuthProvider() {
    debugPrint('DEBUG (Auth): AuthProvider constructor called.');
    _configurePersistence(); // Configure persistence as early as possible

    // We now subscribe to authStateChanges and let the init() method handle the user flow.
    _authStateChangesSubscription =
        FirebaseAuth.instance.authStateChanges().listen((newUser) async {
      debugPrint(
          'DEBUG (Auth): authStateChanges listener: User changed to ${newUser?.uid ?? "null"}');
      // The init() method will call _handleUserLogin once all guest boxes are set.
      // This listener will be used primarily for sign-out and token refresh scenarios
      // after initial app setup.
      if (_isInitialized) {
        if (newUser?.uid != _currentLoadedUserId) {
          debugPrint(
              'DEBUG (Auth): User changed after initialization. Triggering login/logout flow.');
          _handleUserLogin(newUser);
        } else {
          debugPrint(
              'DEBUG (Auth): Same user. Profile listener should be active.');
          _isLoading = false;
          notifyListeners();
        }
      } else {
        debugPrint(
            'DEBUG (Auth): AuthProvider not yet initialized. Waiting for init() call.');
      }
    });
  }

  Future<void> _configurePersistence() async {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      debugPrint('DEBUG (Auth): Firebase persistence set to LOCAL.');
    } catch (e) {
      debugPrint('Error setting persistence: $e');
      // This error (UnimplementedError) is expected on web, so don't treat as critical
    }
  }

  // Call init once, usually from main.dart after Hive is initialized.
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint(
          'DEBUG (Auth): AuthProvider already initialized. Skipping init().');
      return;
    }
    _isInitialized = true;
    _isLoading = true; // Ensure loading is true when init starts
    error = null;
    notifyListeners();
    debugPrint(
        'DEBUG (Auth): AuthProvider init() called. Checking for user...');

    final newUser = FirebaseAuth.instance.currentUser;
    await _handleUserLogin(newUser);

    // After init completes, ensure _isLoading is false as a safety net.
    if (_isLoading) {
      debugPrint(
          'DEBUG (Auth): Forcing _isLoading to false at end of init() as a safety net.');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleUserLogin(User? newUser) async {
    final bool userChanged = newUser?.uid != _currentLoadedUserId;

    if (userChanged) {
      debugPrint(
          'DEBUG (Auth): User ID changed or login/logout detected. Setting isLoading=true.');
      _isLoading =
          true; // Always set loading to true when a user transition begins
      notifyListeners();

      if (_currentLoadedUserId != null) {
        debugPrint(
            'DEBUG (Auth): Disposing user-specific data for old user: $_currentLoadedUserId');
        await _closeUserSpecificBoxes();
      }

      // We'll delay assigning `user` publicly until after user-specific
      // data (Hive boxes) are migrated/opened. This prevents UI widgets from
      // seeing `user != null` and trying to access user-specific boxes that
      // aren't ready yet (which caused assertions/errors on web).
      final String? newUid = newUser?.uid;

      if (newUid != null) {
        debugPrint(
            'DEBUG (Auth): New user logged in: $newUid. Initializing user data.');
        _profileLoadCompleter = Completer<void>(); // Re-initialize completer

        // Perform migration and open user-specific boxes using the UID.
        await _migrateGuestData(newUid);
        await _openUserSpecificBoxes(newUid);

        // Only assign the public `user` reference if opening boxes did not
        // set a non-null error. This keeps the app in a safe state if box
        // opening failed.
        if (error == null) {
          user = newUser; // now safe to assign
          _currentLoadedUserId = newUid; // Update the tracker

          final userDocRef =
              FirebaseFirestore.instance.collection('users').doc(newUid);
          final userDoc = await userDocRef.get();
          if (userDoc.exists && userDoc.data()?['email'] != user!.email) {
            debugPrint(
                'DEBUG (Auth): Updating Firestore user email to match FirebaseAuth.');
            await userDocRef.update({'email': user!.email});
          }

          _listenToUserProfile(newUid); // Start listening to profile
        } else {
          // If there was an error opening boxes, keep user as null and let
          // the UI surface the error (AuthProvider.error) so the user can
          // take recovery steps (e.g., logout/login).
          debugPrint(
              'ERROR (Auth): Aborting user assignment due to earlier error: $error');
        }
      } else {
        // User is null (logged out)
        debugPrint(
            'DEBUG (Auth): User logged out (user is null). Resetting state.');
        _resetProfileData(); // Reset profile data for logged out state
        _isProCustomClaim = false; // Reset custom claim status
        if (_profileLoadCompleter?.isCompleted == false) {
          _profileLoadCompleter?.complete();
        }
        _profileLoadCompleter = null;
        _isLoading = false; // Ensure loading is false on logout
        notifyListeners();
      }
    } else {
      debugPrint(
          'DEBUG (Auth): authStateChanges: User ID is the same (${user?.uid ?? "null"}).');
      if (user != null && _userProfileSubscription == null) {
        debugPrint(
            'DEBUG (Auth): Same user, but profile listener was null. Re-listening.');
        _listenToUserProfile(user!.uid);
      } else if (user != null && _profileLoadCompleter?.isCompleted == false) {
        debugPrint(
            'DEBUG (Auth): Same user, completer active. Completing now if not completed by listener.');
        _profileLoadCompleter?.complete();
      }
      _isLoading = false; // Stop loading, as no major state change occurred
      notifyListeners();
    }
  }

  void _listenToUserProfile(String uid) {
    _userProfileSubscription?.cancel(); // Cancel previous listener if any
    _userProfileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (snapshot) async {
        debugPrint(
            'DEBUG (Auth): User profile snapshot received for UID: $uid. Data exists: ${snapshot.exists}');
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          _displayName = data['displayName'] ?? user?.displayName ?? '';
          profilePictureURL = data['photoURL'] ?? user?.photoURL;
          stripeRole = data['stripeRole'];
          isFounder = data['isFounder'] ?? false;
          themeName = data['themeName'];
          themeMode = data['themeMode'];
          fontSizeScale = (data['fontSizeScale'] as num?)?.toDouble();
          profileFrame = data['profileFrame'];
          fontFamily = data['fontFamily'];

          // 🚀 Promotions: pull from Firestore if available
          if (data['activePromotions'] != null) {
            _activePromotions =
                List<Map<String, dynamic>>.from(data['activePromotions']);
          } else {
            _activePromotions = [];
          }

          // ...
          // Fetch custom claims
          if (user != null) {
            try {
              final idTokenResult = await user!.getIdTokenResult(true);
              _isProCustomClaim = idTokenResult.claims?['isPro'] == true;
              debugPrint(
                  'DEBUG (Auth): Custom claim isPro: $_isProCustomClaim');
            } catch (e) {
              debugPrint('ERROR (Auth): Failed to get ID token result: $e');
              _isProCustomClaim = false;
            }
          } else {
            _isProCustomClaim = false;
          }

          // --- FIX: NOTIFY *AFTER* THE AWAIT ---
          _isLoading = false;
          error = null;
          if (_profileLoadCompleter?.isCompleted == false) {
            _profileLoadCompleter?.complete();
            debugPrint(
                'DEBUG (Auth): _profileLoadCompleter completed by listener.');
          }
          notifyListeners(); // <--- MOVED HERE
        } else {
          _resetProfileData(useAuthObjectDefaults: true);
          debugPrint(
              'DEBUG (Auth): User profile doc does not exist for UID: $uid. Resetting profile data.');
          _isProCustomClaim = false;
          _activePromotions = []; // Clear promotions

          // --- FIX: ALSO NOTIFY IN THE 'ELSE' BLOCK ---
          _isLoading = false;
          error = null;
          // if (_profileLoadCompleter?.isCompleted == false) {
          //   _profileLoadCompleter?.complete();
          //   debugPrint(
          //       'DEBUG (Auth): _profileLoadCompleter completed by listener (user doc does not exist).');
          // }
          notifyListeners();
        }

        // --- REMOVE THE OLD NOTIFY CALLS FROM HERE ---
        // _isLoading = false;  <-- DELETE
        // error = null;        <-- DELETE
        // if (...) { ... }     <-- DELETE
        // notifyListeners();   <-- DELETE
      },
      onError: (e) {
        debugPrint('ERROR (Auth): loading user profile for UID: $uid - $e');
        error = "Failed to load user profile.";
        _isLoading = false;
        _resetProfileData();
        _isProCustomClaim = false;
        _activePromotions = [];
        if (_profileLoadCompleter?.isCompleted == false) {
          _profileLoadCompleter?.completeError(e);
          debugPrint(
              'ERROR (Auth): _profileLoadCompleter completed with error by listener.');
        }
        notifyListeners();
      },
    );
    // Also begin listening for any global broadcast messages targeted to users.
    _startBroadcastListener(uid);
  }

  void _resetProfileData({bool useAuthObjectDefaults = false}) {
    if (useAuthObjectDefaults && user != null) {
      _displayName = user!.displayName ?? user!.email?.split('@').first ?? '';
      profilePictureURL = user!.photoURL;
    } else {
      _displayName = '';
      profilePictureURL = null;
    }
    stripeRole = null;
    isFounder = false;
    themeName = null;
    themeMode = null;
    fontSizeScale = null;
    profileFrame = null;
    fontFamily = null;
    _isProCustomClaim = false; // Reset custom claim status
    debugPrint('DEBUG (Auth): Profile data reset.');
  }

  /// Start listening to a single broadcast document which admins can toggle
  /// via the console. This sets [_latestBroadcast] when a new enabled message
  /// appears and the current user/guest hasn't marked it seen yet.
  Future<void> _startBroadcastListener(String? uid) async {
    // Safer approach: Cancel previous listener first
    await _broadcastSubscription?.cancel();
    if (uid == null) {
      _broadcastSubscription = null;
      return;
    }

    // Helper: Safely check seen status without crashing on box errors
    bool hasSeenBroadcast(String broadcastId) {
      try {
        final key = uid != null ? 'lastSeen_$uid' : 'lastSeen_guest';
        // Check if box is actually open and valid before accessing
        if (_guestBroadcastSeenBox == null || !_guestBroadcastSeenBox!.isOpen) {
          return false; // Default to not seen if box is unavailable/initializing
        }
        final lastSeen = _guestBroadcastSeenBox!.get(key);
        return lastSeen == broadcastId;
      } catch (e) {
        debugPrint('AUTH: Box error in hasSeenBroadcast: $e');
        return false;
      }
    }

    final docRef = FirebaseFirestore.instance
        .collection('broadcasts')
        .doc('latest_message');

    try {
      // 1. Immediate fetch attempt (Fast UI update)
      try {
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final enabled = data['isEnabled'] == true;
          final broadcastId = data['id']?.toString() ?? snapshot.id;

          if (enabled && !hasSeenBroadcast(broadcastId)) {
            _latestBroadcast = data;
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('AUTH: Initial broadcast fetch failed: $e');
      }

      // 2. Real-time listener
      _broadcastSubscription = docRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data() as Map<String, dynamic>;
        final enabled = data['isEnabled'] == true;
        final broadcastId = data['id']?.toString() ?? snapshot.id;

        if (enabled && !hasSeenBroadcast(broadcastId)) {
          _latestBroadcast = data;
          notifyListeners();
        }
      }, onError: (e) {
        debugPrint('AUTH: broadcast listener error: $e');
        // Do not cancel here, retry logic is handled by Firestore SDK usually,
        // but we swallow the error to prevent crash.
      });
    } catch (e) {
      debugPrint('AUTH: cannot read broadcasts/latest_message: $e');
      _broadcastSubscription = null;
    }
  }

  // --- Hive Box Management ---

  Future<void> _migrateGuestData(String uid) async {
    // NOTES MIGRATION
    if (_guestNotesBox.isNotEmpty) {
      debugPrint("DEBUG (Auth): Migrating guest notes to user: $uid");
      final userNotesBox = await Hive.openBox<Note>('notes_$uid');
      for (var note in _guestNotesBox.values) {
        await userNotesBox.add(note);
      }
      await _guestNotesBox
          .clear(); // Clear guest notes after successful migration
      await userNotesBox.close(); // Close the user-specific box temporarily
      debugPrint("DEBUG (Auth): Guest notes migration complete.");
    }

    // FLASHCARD DECKS MIGRATION
    if (_guestFlashcardDecksBox.isNotEmpty) {
      debugPrint("DEBUG (Auth): Migrating guest flashcard decks to user: $uid");
      final userFlashcardDecksBox = await Hive.openBox<FlashcardDeck>(
        'flashcardDecks_$uid',
      );
      for (var deck in _guestFlashcardDecksBox.values) {
        await userFlashcardDecksBox.add(deck);
      }
      await _guestFlashcardDecksBox.clear();
      await userFlashcardDecksBox.close();
      debugPrint("DEBUG (Auth): Guest flashcard decks migration complete.");
    }

    // SUBJECTS MIGRATION
    if (_guestSubjectsBox.isNotEmpty) {
      debugPrint("DEBUG (Auth): Migrating guest subjects to user: $uid");
      final userSubjectsBox = await Hive.openBox<Subject>('subjects_$uid');
      for (var subject in _guestSubjectsBox.values) {
        await userSubjectsBox.add(subject);
      }
      await _guestSubjectsBox.clear();
      await userSubjectsBox.close();
      debugPrint("DEBUG (Auth): Guest subjects migration complete.");
    }

    // TASKS MIGRATION
    if (_guestTasksBox.isNotEmpty) {
      debugPrint("DEBUG (Auth): Migrating guest tasks to user: $uid");
      final userTasksBox = await Hive.openBox<Task>('tasks_$uid');
      for (var task in _guestTasksBox.values) {
        await userTasksBox.add(task);
      }
      await _guestTasksBox.clear();
      await userTasksBox.close();
      debugPrint("DEBUG (Auth): Guest tasks migration complete.");
    }

    // RESUME DATA MIGRATION
    if (_guestResumeDataBox.isNotEmpty) {
      debugPrint("DEBUG (Auth): Migrating guest resume data to user: $uid");
      final userResumeDataBox = await Hive.openBox<ResumeData>(
        'resumeData_$uid',
      );
      for (var resumeData in _guestResumeDataBox.values) {
        await userResumeDataBox.add(resumeData);
      }
      await _guestResumeDataBox.clear();
      await userResumeDataBox.close();
      debugPrint("DEBUG (Auth): Guest resume data migration complete.");
    }
  }

  Future<void> _openUserSpecificBoxes(String uid) async {
    debugPrint(
        "DEBUG (Auth): Attempting to open user-specific boxes for UID: $uid");
    // Clear any previous error before attempting to open boxes
    error = null; // IMPORTANT: Clear error at the start of this method

    try {
      _notesBox = await Hive.openBox<Note>('notes_$uid');
      debugPrint(
        'DEBUG (Auth): notes_$uid opened successfully. Is open: ${_notesBox!.isOpen}',
      );

      _flashcardDecksBox = await Hive.openBox<FlashcardDeck>(
        'flashcardDecks_$uid',
      );
      debugPrint(
        'DEBUG (Auth): flashcardDecks_$uid opened successfully. Is open: ${_flashcardDecksBox!.isOpen}',
      );

      _aiTeacherSessionsBox = await Hive.openBox<AITeacherSession>(
        'aiTeacherSessions_$uid',
      );
      debugPrint(
        'DEBUG (Auth): aiTeacherSessions_$uid opened successfully. Is open: ${_aiTeacherSessionsBox!.isOpen}',
      );

      _aiInterviewSessionsBox = await Hive.openBox<AIInterviewSession>(
        'aiInterviewSessions_$uid',
      );
      debugPrint(
        'DEBUG (Auth): aiInterviewSessions_$uid opened successfully. Is open: ${_aiInterviewSessionsBox!.isOpen}',
      );

      _subjectsBox = await Hive.openBox<Subject>('subjects_$uid');
      debugPrint(
        'DEBUG (Auth): subjects_$uid opened successfully. Is open: ${_subjectsBox!.isOpen}',
      );

      _savedDocumentsBox =
          await Hive.openBox<SavedDocument>('savedDocuments_$uid');

      // --- START: ROBUST FIX FOR CORRUPTED TASKS DATA ---
      final tasksBoxName = 'tasks_$uid';
      try {
        _tasksBox = await Hive.openBox<Task>(tasksBoxName);
        // Verification step: Accessing values catches corruption that openBox() might miss.
        // This prevents crashes later in the UI layer (e.g., PlannerScreen).
        _tasksBox!.values.length; // This line is the key verification step.
        debugPrint(
            'DEBUG (Auth): $tasksBoxName opened and verified successfully. Is open: ${_tasksBox!.isOpen}');
      } catch (e) {
        debugPrint(
            'ERROR (Auth): Caught corruption in $tasksBoxName: $e. Deleting and recreating box.');

        // Ensure the box is closed before deleting it to avoid file locks.
        if (Hive.isBoxOpen(tasksBoxName)) {
          await Hive.box(tasksBoxName).close();
        }
        await Hive.deleteBoxFromDisk(tasksBoxName);

        // Reopen the box; it will now be fresh and empty.
        _tasksBox = await Hive.openBox<Task>(tasksBoxName);
        debugPrint(
            'DEBUG (Auth): $tasksBoxName recreated after corruption. Is open: ${_tasksBox!.isOpen}');

        // Inform the user that data was reset.
        error =
            "Your tasks data was corrupted and has been reset. We apologize for the inconvenience.";
        notifyListeners();
      }
      // --- END: ROBUST FIX FOR CORRUPTED TASKS DATA ---

      _resumeDataBox = await Hive.openBox<ResumeData>('resumeData_$uid');
      debugPrint(
        'DEBUG (Auth): resumeData_$uid opened successfully. Is open: ${_resumeDataBox!.isOpen}',
      );

      _chatMessagesBox = await Hive.openBox<HiveChatMessage>(
        'chatMessages_$uid',
      );
      debugPrint(
        'DEBUG (Auth): chatMessages_$uid opened successfully. Is open: ${_chatMessagesBox!.isOpen}',
      );
      _flashcardsBox = await Hive.openBox<Flashcard>('flashcards_$uid');
      debugPrint(
        'DEBUG (Auth): flashcards_$uid opened successfully. Is open: ${_flashcardsBox!.isOpen}',
      );

      debugPrint(
        "DEBUG (Auth): All user-specific boxes assigned and verified as open for UID: $uid",
      );
    } catch (e) {
      debugPrint(
          "ERROR (Auth): opening user-specific Hive boxes for UID $uid: $e");
      // Set error if other boxes fail to open
      error =
          "Failed to open user-specific data. Please try logging out and in again.";
      notifyListeners();
    }
  }

  Future<void> _closeUserSpecificBoxes() async {
    debugPrint("DEBUG (Auth): Attempting to close user-specific boxes.");
    try {
      await Future.wait([
        if (_notesBox != null && _notesBox!.isOpen) _notesBox!.close(),
        if (_flashcardDecksBox != null && _flashcardDecksBox!.isOpen)
          _flashcardDecksBox!.close(),
        if (_aiTeacherSessionsBox != null && _aiTeacherSessionsBox!.isOpen)
          _aiTeacherSessionsBox!.close(),
        if (_aiInterviewSessionsBox != null && _aiInterviewSessionsBox!.isOpen)
          _aiInterviewSessionsBox!.close(),
        if (_subjectsBox != null && _subjectsBox!.isOpen) _subjectsBox!.close(),
        if (_tasksBox != null && _tasksBox!.isOpen) _tasksBox!.close(),
        if (_resumeDataBox != null && _resumeDataBox!.isOpen)
          _resumeDataBox!.close(),
        if (_chatMessagesBox != null && _chatMessagesBox!.isOpen)
          _chatMessagesBox!.close(),
        if (_flashcardsBox != null && _flashcardsBox!.isOpen)
          _flashcardsBox!.close(),
        if (_savedDocumentsBox != null && _savedDocumentsBox!.isOpen)
          _savedDocumentsBox!.close(),
      ]);
    } catch (e) {
      debugPrint("ERROR (Auth): closing one or more user-specific boxes: $e");
    }

    _notesBox = null;
    _flashcardDecksBox = null;
    _aiTeacherSessionsBox = null;
    _aiInterviewSessionsBox = null;
    _subjectsBox = null;
    _tasksBox = null;
    _resumeDataBox = null;
    _chatMessagesBox = null;
    _flashcardsBox = null;
    _savedDocumentsBox = null;

    debugPrint("DEBUG (Auth): All user-specific box references set to null.");
  }

  @override
  void dispose() {
    debugPrint(
        'DEBUG (Auth): AuthProvider dispose() called. Cancelling streams.');
    _authStateChangesSubscription?.cancel();
    _userProfileSubscription?.cancel();
    _closeUserSpecificBoxes(); // Ensure boxes are closed on dispose
    super.dispose();
  }

  // --- Authentication Methods ---

  Future<bool> signUp(
    String email,
    String password, {
    String? referralCode,
  }) async {
    _isLoading = true;
    error = null;
    notifyListeners();

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final newUser = cred.user;
      if (newUser == null) throw Exception("User creation failed.");

      await _secureStorage.write(
        key: 'auth_token',
        value: await newUser.getIdToken(),
      );

      final defaultDisplayName = email.split('@').first;
      await newUser.updateDisplayName(defaultDisplayName);

      // --- ROBUST FOUNDER LOGIC ---
      String initialStripeRole = 'free';
      bool founderDiscount = false;
      try {
        // This might fail if rules are strict, so we wrap it.
        final userCountSnapshot =
            await FirebaseFirestore.instance.collection('users').count().get();
        final totalUsers = userCountSnapshot.count ?? 0;
        if (totalUsers < 1000) {
          founderDiscount = true;
          initialStripeRole = 'founder_discount';
        }
      } catch (e) {
        debugPrint(
            "WARNING: Founder check failed: $e. Proceeding with signup.");
        founderDiscount = false;
        initialStripeRole = 'free';
        // We continue execution. The user gets created, just without the flag.
      }
      // -----------------------------

      String? referredBy;
      if (referralCode != null && referralCode.isNotEmpty) {
        try {
          final HttpsCallable callable =
              FirebaseFunctions.instance.httpsCallable('validateReferralCode');
          final result = await callable.call<Map<String, dynamic>>({
            'code': referralCode,
          });
          referredBy = result.data['referrerId'];
        } catch (e) {
          debugPrint("Referral validation failed: $e");
        }
      }

      if (referredBy != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(newUser.uid)
            .set({'referredBy': referredBy}, SetOptions(merge: true));
      }

      // --- NEW MOBILE GRANT LOGIC ---
      Map<String, dynamic> subscriptionData = {
        'platform': 'none',
        'status': 'free',
        'productId': null,
        'expiresDate': null,
      };

      // Check if we are on mobile (Android/iOS)
      final bool isMobile = !kIsWeb;

      // If on mobile AND used a valid referral code, grant 30 days immediately
      if (isMobile && referredBy != null) {
        debugPrint("DEBUG: Mobile Signup with Referral - Granting 30 Days.");
        subscriptionData = {
          'platform': 'referral_grant',
          'status': 'active',
          'productId': 'referral_bonus',
          // Grant 30 days from now
          'expiresDate':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Manually reward the referrer since we won't save 'referredBy' in the way Web expects
        try {
          FirebaseFunctions.instance
              .httpsCallable('rewardReferrer')
              .call({'referrerId': referredBy});
        } catch (e) {
          debugPrint("Error rewarding referrer: $e");
        }
      }
      // -----------------------------

      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.uid)
          .set({
        'email': email,
        'displayName': defaultDisplayName,
        'createdAt': FieldValue.serverTimestamp(),
        'stripeRole': initialStripeRole,
        //'isFounder': founderDiscount,
        'photoURL': null,
        'uid_prefix': newUser.uid.substring(0, 8).toUpperCase(),
        'subscription': subscriptionData,
        if (kIsWeb && referredBy != null) 'referredBy': referredBy,
        // Track it internally for mobile so we know they used it
        if (!kIsWeb && referredBy != null) 'mobileReferralUsed': referredBy,
      }, SetOptions(merge: true));

      return true;
    } on FirebaseAuthException catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      error = 'An unexpected error occurred during sign up.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    error = null;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // FIX: Force navigation to Home/Dashboard immediately on success
      // This clears the LoginScreen from the stack so you don't see the "reload" glitch.
      // navigatorKey.currentState?.popUntil((route) => route.isFirst);

      return true;
    } catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- Profile Management ---

  Future<void> updateDisplayName(String newDisplayName) async {
    if (user == null) return;
    _isLoading = true;
    error = null;
    notifyListeners();

    try {
      await user!.updateDisplayName(newDisplayName);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'displayName': newDisplayName});
      error = null;
    } catch (e) {
      error = 'Failed to update display name.';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfilePicture() async {
    if (user == null) {
      error = "User not logged in. Cannot update profile picture.";
      notifyListeners();
      return;
    }

    final imagePicker = ImagePicker();
    final XFile? file = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // compress to save bandwidth
    );

    if (file == null) {
      debugPrint('DEBUG (Auth): Profile picture selection cancelled.');
      return;
    }

    _isLoading = true;
    error = null;
    notifyListeners();

    try {
      final ref =
          FirebaseStorage.instance.ref('profile_pics/${user!.uid}/profile.jpg');
      UploadTask uploadTask;

      if (kIsWeb) {
        uploadTask = ref.putData(await file.readAsBytes());
      } else {
        uploadTask = ref.putFile(File(file.path));
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String photoURL = await snapshot.ref.getDownloadURL();

      await user!.updatePhotoURL(photoURL);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'photoURL': photoURL});

      error = null;
      debugPrint(
          'DEBUG (Auth): Profile picture updated successfully: $photoURL');
    } on FirebaseException catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      debugPrint('ERROR (Auth): Firebase Storage error: $e');
    } catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      debugPrint('ERROR (Auth): Unexpected image upload error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    error = null;
    notifyListeners();
    bool success = false;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      success = true;
    } on FirebaseAuthException catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);

      // Preserve extra clarity for common cases
      if (e.code == 'user-not-found') {
        error = 'No user found for that email.';
      } else if (e.code == 'invalid-email') {
        error = 'The email address is not valid.';
      }

      success = false;
    } catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      success = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return success;
  }

  // --- Account Management ---

  Future<void> _reauthenticate(String password) async {
    if (user == null) {
      throw Exception('Not logged in.');
    }
    if (user!.email == null) {
      throw Exception('User email is missing for reauthentication.');
    }
    final cred = EmailAuthProvider.credential(
      email: user!.email!,
      password: password,
    );
    await user!.reauthenticateWithCredential(cred);
  }

  // Find the existing updateUserEmail function and replace it with this:
  Future<void> updateUserEmail(String newEmail, String currentPassword) async {
    if (user == null) return;
    _isLoading = true;
    error = null;
    notifyListeners();

    try {
      // 1. Reauthenticate to ensure permission
      await _reauthenticate(currentPassword);

      // 2. Verify before update (standard safest path)
      await user!.verifyBeforeUpdateEmail(newEmail);

      // 3. CRITICAL FIX: Force logout.
      // Firebase tokens invalidate immediately on email change.
      // Trying to reload() or continue here causes the app to crash.
      await logout();
    } on FirebaseAuthException catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
    // Note: 'finally' block removed because logout() handles state reset
  }

  Future<void> updateUserPassword(
    String newPassword,
    String currentPassword,
  ) async {
    if (user == null) return;
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _reauthenticate(currentPassword);
      await user!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount(String password,
      {VoidCallback? onPreDeleteAction}) async {
    if (user == null) {
      throw Exception('Not logged in.');
    }

    _isLoading = true;
    error = null;
    notifyListeners();

    final uid = user!.uid;

    try {
      // 1) Reauthenticate FIRST. If this fails, we throw, and the UI stays put.
      await _reauthenticate(password);

      // 2) FIRE AND FLEE: The password is correct.
      // We trigger the callback to navigate the user to the Login screen immediately.
      // This prevents them from seeing the "Theme Strip" crash during the 4s wait.
      if (onPreDeleteAction != null) {
        onPreDeleteAction();
      }

      // 3) Trigger Stripe Cancellation (The 4-second wait)
      // The user is already safely on the login screen now.
      try {
        debugPrint(
            "AUTH(deleteAccount): Triggering Stripe cancellation command...");
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('stripe_commands')
            .add({
          'command': 'cancel_subscription',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Wait a moment for the Cloud Function to execute
        await Future.delayed(const Duration(seconds: 4));
      } catch (e) {
        debugPrint(
            'AUTH(deleteAccount): Failed to trigger Stripe cancellation: $e');
      }

      // 4) Cancel listeners and close user-specific boxes
      _userProfileSubscription?.cancel();
      _userProfileSubscription = null;
      await _closeUserSpecificBoxes();

      // 5) Firestore cleanup
      try {
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(uid);

        final List<String> subcollectionsToTry = [
          'portal_links',
          'stripe_commands',
          'checkout_sessions',
        ];
        for (final sub in subcollectionsToTry) {
          try {
            final colRef = userDocRef.collection(sub);
            final snap = await colRef.limit(50).get();
            for (final d in snap.docs) {
              await d.reference.delete();
            }
          } catch (e) {
            debugPrint('AUTH: subcollection cleanup $sub error: $e');
          }
        }
        await userDocRef.delete();
      } catch (e) {
        debugPrint('AUTH(deleteAccount): Firestore cleanup failed: $e');
      }

      // 6) Storage cleanup
      try {
        final storage = FirebaseStorage.instance;
        final List<String> storagePrefixes = [
          'profile_pics/$uid',
          'uploads/$uid',
          'user_files/$uid',
        ];

        for (final prefix in storagePrefixes) {
          try {
            final ref = storage.ref(prefix);
            final listResult = await ref.listAll();
            for (final item in listResult.items) {
              await item.delete();
            }
          } catch (e) {
            debugPrint('AUTH: Storage cleanup $prefix error: $e');
          }
        }
      } catch (e) {
        debugPrint('AUTH(deleteAccount): Storage cleanup failed: $e');
      }

      // 7) Hive cleanup
      try {
        final List<String> boxNames = [
          'notes_$uid',
          'flashcardDecks_$uid',
          'aiTeacherSessions_$uid',
          'aiInterviewSessions_$uid',
          'subjects_$uid',
          'tasks_$uid',
          'resumeData_$uid',
          'chatMessages_$uid',
          'flashcards_$uid',
        ];

        for (final name in boxNames) {
          try {
            if (Hive.isBoxOpen(name)) {
              await Hive.box(name).close();
            }
            await Hive.deleteBoxFromDisk(name);
          } catch (e) {
            debugPrint('AUTH: Hive cleanup $name error: $e');
          }
        }
      } catch (e) {
        debugPrint('AUTH(deleteAccount): Hive cleanup failed: $e');
      }

      // 8) Secure storage & Auth Delete
      try {
        await _secureStorage.deleteAll();
      } catch (e) {
        debugPrint('AUTH: secure storage delete failed: $e');
      }

      try {
        await user!.delete();
      } catch (e) {
        debugPrint('ERROR (Auth): Firebase user.delete() failed: $e');
        rethrow;
      }

      // 9) Reset local state
      user = null;
      _currentLoadedUserId = null;
      _resetProfileData();
      _isProCustomClaim = false;
      _isLoading = false;
      error = null;
      // We do NOT notify listeners here because the user has already navigated away.
    } on FirebaseAuthException catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      error = ErrorUtils.getFriendlyMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  List<String> get activePromotionTypes {
    return _activePromotions.map((promo) => promo['type'] as String).toList();
  }

  // --- Preferences ---

  Future<void> logout() async {
    if (user == null) return;

    try {
      // Cancel listeners
      await _broadcastSubscription?.cancel(); // Add await
      _broadcastSubscription = null;
      await _userProfileSubscription?.cancel();
      _userProfileSubscription = null;

      // Close Hive boxes
      await _closeUserSpecificBoxes();

      // Clear secure storage
      try {
        await _secureStorage.deleteAll();
      } catch (e) {
        debugPrint("AUTH(logout): secure storage cleanup failed: $e");
      }

      // Firebase sign out
      await FirebaseAuth.instance.signOut();

      // Reset state
      user = null;
      _currentLoadedUserId = null;
      _resetProfileData();
      _isProCustomClaim = false;
      error = null;
      _isLoading = false;
      notifyListeners();

      debugPrint("DEBUG (Auth): User logged out successfully.");
    } catch (e) {
      debugPrint("ERROR (Auth): logout failed: $e");
      rethrow;
    }
  }

  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    if (user == null) return;
    _isLoading = true;
    error = null;
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update(preferences);
      error = null;
    } catch (e) {
      error = 'Failed to save preferences.';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
