import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  final Set<String> _seenTutorials = {};
  bool _isInitialized = false;

  TutorialProvider() {
    // Initialization is now handled by an explicit call to init() from main.dart
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    final seen = _prefs.getStringList('seenTutorials') ?? [];
    _seenTutorials.addAll(seen);
    _isInitialized = true;
  }

  bool hasSeen(String tutorialKey) {
    return _seenTutorials.contains(tutorialKey);
  }

  Future<void> markAsSeen(String tutorialKey) async {
    if (!_isInitialized) await init(); // Should not happen, but as a safeguard.
    if (_seenTutorials.add(tutorialKey)) {
      await _prefs.setStringList('seenTutorials', _seenTutorials.toList());
      notifyListeners();
    }
  }
}
