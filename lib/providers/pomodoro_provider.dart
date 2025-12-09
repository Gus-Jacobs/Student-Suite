import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:student_suite/providers/auth_provider.dart';

class PomodoroProvider with ChangeNotifier {
  // State
  late int _workDurationInSeconds;
  late int _secondsLeft;
  int _sessions = 0;
  Timer? _timer;
  bool _running = false;
  List<DateTime> _history = [];
  bool _isPomodoroScreenVisible = false;
  String? _userId;

  // Event for session completion
  final _sessionCompleteController = StreamController<void>.broadcast();
  Stream<void> get onSessionComplete => _sessionCompleteController.stream;

  // Getters
  bool get isRunning => _running;
  int get workDurationInSeconds => _workDurationInSeconds;
  int get secondsLeft => _secondsLeft;
  int get sessions => _sessions;
  List<DateTime> get history => _history;
  bool get isPomodoroScreenVisible => _isPomodoroScreenVisible;

  // Setter to update visibility and notify listeners
  set isPomodoroScreenVisible(bool value) {
    if (_isPomodoroScreenVisible != value) {
      _isPomodoroScreenVisible = value;
      notifyListeners();
    }
  }

  String get timeString {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PomodoroProvider() {
    _workDurationInSeconds = 25 * 60;
    _secondsLeft = _workDurationInSeconds;
  }

  /// Called by ChangeNotifierProxyProvider when AuthProvider updates.
  void update(AuthProvider authProvider) {
    final newUserId = authProvider.user?.uid;

    // If the user has changed, reset the state.
    if (_userId != newUserId) {
      _userId = newUserId;
      _resetForNewUser();
    }
  }

  void _resetForNewUser() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _sessions = 0;
    _history = [];
    _loadState();
  }

  Future<void> _loadState() async {
    if (_userId == null) {
      // No user, reset to defaults
      _sessions = 0;
      _history = [];
      _workDurationInSeconds = 25 * 60;
      _secondsLeft = _workDurationInSeconds;
      notifyListeners();
      return;
    }
    final box = Hive.box('pomodoro');
    _sessions = box.get('sessions_$_userId', defaultValue: 0);
    final historyList =
        box.get('history_$_userId', defaultValue: <String>[]) as List;
    _history =
        historyList.map((s) => DateTime.tryParse(s) ?? DateTime.now()).toList();
    _workDurationInSeconds =
        box.get('workDuration_$_userId', defaultValue: 25 * 60);
    _secondsLeft = _workDurationInSeconds;
    notifyListeners();
  }

  Future<void> _saveState() async {
    if (_userId == null) return;
    final box = Hive.box('pomodoro');
    await box.put('sessions_$_userId', _sessions);
    await box.put('history_$_userId',
        _history.map((dt) => dt.toIso8601String()).toList());
    await box.put('workDuration_$_userId', _workDurationInSeconds);
  }

  void start() {
    if (_running) return;
    _running = true;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        _secondsLeft--;
        notifyListeners();
      } else {
        _sessionCompleteController.add(null);
        _sessions++;
        _history.insert(0, DateTime.now());
        if (_history.length > 10) _history = _history.sublist(0, 10);
        _saveState();
        reset();
      }
    });
  }

  void pause() {
    if (!_running) return;
    _timer?.cancel();
    _running = false;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _running = false;
    _secondsLeft = _workDurationInSeconds;
    notifyListeners();
  }

  void setWorkDuration(int minutes) {
    _workDurationInSeconds = minutes * 60;
    _saveState();
    reset();
  }

  Future<void> clearHistory() async {
    if (_userId == null) return;
    final box = Hive.box('pomodoro');
    await box.put('history_$_userId', <String>[]);
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionCompleteController.close();
    super.dispose();
  }
}
