import 'package:flutter/foundation.dart';

/// Utility class for normalizing error messages across the app.
class ErrorUtils {
  /// Converts raw errors into simplified user-friendly messages.
  /// In debug/dev builds, extra [context] info is prepended for easier debugging.
  static String getFriendlyMessage(Object error, {String? context}) {
    String baseMessage;

    if (error is String) {
      baseMessage = error;
    } else if (error is Exception) {
      final msg = error.toString();

      // --- FirebaseAuth Errors ---
      if (msg.contains('invalid-email')) {
        baseMessage = 'Invalid email address. Please check and try again.';
      } else if (msg.contains('user-not-found') ||
          msg.contains('wrong-password')) {
        baseMessage = 'Invalid email or password.';
      } else if (msg.contains('email-already-in-use')) {
        baseMessage = 'This email is already registered.';
      } else if (msg.contains('weak-password')) {
        baseMessage = 'Password is too weak. Use at least 6 characters.';
      } else if (msg.contains('network-request-failed')) {
        baseMessage = 'Network error. Please check your connection.';
      } else if (msg.contains('permission-denied')) {
        baseMessage =
            'Permission denied. Please check your subscription or access.';
      } else if (msg.contains('payment')) {
        baseMessage =
            'Payment failed. Please check your card or subscription status.';
      } else {
        baseMessage = kReleaseMode
            ? 'Something went wrong. Please try again.'
            : msg; // Full error in dev mode
      }
    } else {
      baseMessage =
          kReleaseMode ? 'An unexpected error occurred.' : error.toString();
    }

    // Add optional context tags in dev/debug mode
    if (!kReleaseMode && context != null) {
      return "[$context] $baseMessage";
    }

    return baseMessage;
  }
}
