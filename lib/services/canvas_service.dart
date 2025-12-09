import 'dart:convert';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/canvas_model.dart';

// =======================================================================
// IMPORTANT: CONFIGURATION REQUIRED
// 1. Get these from your Canvas instance's developer keys section
const String _clientId = "YOUR_CLIENT_ID";
const String _clientSecret = "YOUR_CLIENT_SECRET";

// 2. This must match the Redirect URI in your Canvas Developer Key settings.
//    You also need to configure this in your app (e.g., AndroidManifest.xml for Android)
const String _redirectUri = "studentsuite://auth";
const String _callbackUrlScheme = "studentsuite";

// Automatically enables demo mode if placeholder keys are present.
const bool _isDemoMode = _clientId == "YOUR_CLIENT_ID";
// =======================================================================

class CanvasService {
  final _secureStorage = const FlutterSecureStorage();
  final String _tokenKey = 'canvas_access_token';

  /// Initiates the OAuth 2.0 login flow to get an access token.
  Future<String?> loginWithOAuth(String domain) async {
    if (_isDemoMode) {
      // ignore: avoid_print
      print(
          'CANVAS DEMO MODE: Using mock data because no developer keys were provided.');
      await Future.delayed(const Duration(seconds: 1)); // Simulate network call
      const demoToken = 'demo_canvas_token';
      await _secureStorage.write(key: _tokenKey, value: demoToken);
      // Store the domain used for this token
      await _secureStorage.write(key: 'canvas_domain', value: domain);
      return demoToken;
    }

    if (_clientId == "YOUR_CLIENT_ID" ||
        _clientSecret == "YOUR_CLIENT_SECRET") {
      throw Exception(
          "Canvas Client ID/Secret not configured in canvas_service.dart. Please get these from your Canvas developer keys.");
    }

    final authUrl = Uri.parse(
        'https://$domain/login/oauth2/auth?client_id=$_clientId&response_type=code&redirect_uri=$_redirectUri&state=123');

    try {
      // 1. Get authorization code from user login
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _callbackUrlScheme,
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) throw Exception('Authorization code not found.');

      // 2. Exchange code for an access token
      final tokenUrl = Uri.parse('https://$domain/login/oauth2/token');
      final response = await http.post(tokenUrl, body: {
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'redirect_uri': _redirectUri,
        'code': code,
      });

      if (response.statusCode == 200) {
        final credentials = json.decode(response.body);
        final accessToken = credentials['access_token'];
        await _secureStorage.write(key: _tokenKey, value: accessToken);
        await _secureStorage.write(key: 'canvas_domain', value: domain);
        return accessToken;
      } else {
        throw Exception('Failed to get access token: ${response.body}');
      }
    } catch (e) {
      // Re-throw with a more user-friendly message or log the error
      throw Exception('Canvas login failed: $e');
    }
  }

  /// Gets the stored token from secure storage.
  Future<String?> getStoredToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  /// Gets the stored domain from secure storage.
  Future<String?> getStoredDomain() async {
    return await _secureStorage.read(key: 'canvas_domain');
  }

  /// Deletes the stored token to disconnect the user.
  Future<void> disconnect() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: 'canvas_domain');
  }

  /// Helper to make authenticated GET requests to the Canvas API.
  Future<http.Response> _get(String domain, String path, String token) async {
    final url = Uri.parse('https://$domain/api/v1/$path');
    return await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  /// Fetches the list of active courses for the authenticated user.
  Future<List<CanvasCourse>> fetchCourses(String domain, String token) async {
    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _getMockCourses();
    }

    final response =
        await _get(domain, 'courses?enrollment_state=active', token);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      return data.map((c) => CanvasCourse.fromJson(c)).toList();
    } else {
      throw Exception('Failed to fetch courses: ${response.body}');
    }
  }

  /// Fetches assignments for a specific course.
  Future<List<CanvasAssignment>> fetchAssignments(
      String domain, String token, String courseId) async {
    if (_isDemoMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return _getMockAssignments(courseId);
    }

    final response = await _get(domain, 'courses/$courseId/assignments', token);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      return data.map((a) => CanvasAssignment.fromJson(a)).toList();
    } else {
      throw Exception(
          'Failed to fetch assignments for course $courseId: ${response.body}');
    }
  }

  // --- Mock Data for Demo Mode ---

  List<CanvasCourse> _getMockCourses() {
    return [
      CanvasCourse(id: '101', name: 'CS 101: Intro to Programming'),
      CanvasCourse(id: '202', name: 'ENG 202: World Literature'),
      CanvasCourse(id: '303', name: 'MATH 303: Linear Algebra'),
    ];
  }

  List<CanvasAssignment> _getMockAssignments(String courseId) {
    final now = DateTime.now();
    switch (courseId) {
      case '101':
        return [
          CanvasAssignment(
              id: 'cs_a1',
              name: 'Homework 1: Variables',
              dueDate: now.add(const Duration(days: 2))),
          CanvasAssignment(
              id: 'cs_a2',
              name: 'Lab 1: Hello World',
              dueDate: now.add(const Duration(days: 4))),
          CanvasAssignment(
              id: 'cs_a3',
              name: 'Midterm Project',
              dueDate: now.add(const Duration(days: 14))),
        ];
      case '202':
        return [
          CanvasAssignment(
              id: 'eng_a1',
              name: 'Essay: The Great Gatsby',
              dueDate: now.add(const Duration(days: 7))),
          CanvasAssignment(
              id: 'eng_a2',
              name: 'Reading Quiz 3',
              dueDate: now.add(const Duration(days: 9))),
        ];
      default:
        return [];
    }
  }
}
