import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/canvas_service.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/canvas_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'dart:ui'; // For ImageFilter

class CanvasSyncScreen extends StatefulWidget {
  const CanvasSyncScreen({super.key});

  @override
  State<CanvasSyncScreen> createState() => _CanvasSyncScreenState();
}

enum SyncStatus { disconnected, connecting, connected, error }

class _CanvasSyncScreenState extends State<CanvasSyncScreen> {
  final CanvasService _canvasService = CanvasService();
  SyncStatus _status = SyncStatus.connecting;
  final TextEditingController _domainController = TextEditingController();
  String? _token;
  String? _canvasDomain;
  List<CanvasCourse> _courses = [];
  Map<String, List<CanvasAssignment>> _assignmentsByCourse = {};
  final Map<String, bool> _isCourseLoading = {};
  String? _errorMessage;
  Set<String> _importedAssignmentIds = {};

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
    _loadDomain();
    _loadImportedAssignmentIds();
  }

  Future<void> _loadImportedAssignmentIds() async {
    final box = Hive.box<Task>('tasks');
    final canvasTasks = box.values.where((task) => task.source == 'canvas');
    setState(() {
      _importedAssignmentIds = canvasTasks.map((task) => task.id).toSet();
    });
  }

  Future<void> _loadDomain() async {
    final prefs = await SharedPreferences.getInstance();
    final domain = prefs.getString('canvas_domain_preference');
    if (domain != null) {
      setState(() {
        _domainController.text = domain;
      });
    }
  }

  Future<void> _checkConnectionStatus() async {
    setState(() => _status = SyncStatus.connecting);
    try {
      final token = await _canvasService.getStoredToken();
      if (token != null) {
        await _fetchCourses(token);
      } else {
        setState(() => _status = SyncStatus.disconnected);
      }
    } catch (e) {
      setState(() {
        _status = SyncStatus.error;
        _errorMessage = "Failed to check connection: ${e.toString()}";
      });
    }
  }

  Future<void> _loginAndFetchCourses() async {
    setState(() => _status = SyncStatus.connecting);
    final domain = _domainController.text.trim();
    if (domain.isEmpty) {
      setState(() {
        _status = SyncStatus.error;
        _errorMessage = "Please enter your school's Canvas domain.";
      });
      return;
    }
    try {
      final token = await _canvasService.loginWithOAuth(domain);
      if (token != null) {
        await _fetchCourses(token);
      } else {
        setState(() {
          _status = SyncStatus.error;
          _errorMessage = "Login was cancelled or failed.";
        });
      }
    } catch (e) {
      setState(() {
        _status = SyncStatus.error;
        _errorMessage = "Failed to connect: ${e.toString()}";
      });
    }
  }

  Future<void> _fetchCourses(String token) async {
    try {
      final domain = await _canvasService.getStoredDomain();
      if (domain == null) {
        throw Exception("Canvas domain not found after login.");
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('canvas_domain_preference', domain);

      final courses = await _canvasService.fetchCourses(domain, token);
      setState(() {
        _status = SyncStatus.connected;
        _token = token;
        _canvasDomain = domain;
        _courses = courses;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _status = SyncStatus.error;
        _errorMessage = "Failed to fetch courses: ${e.toString()}";
      });
    }
  }

  Future<void> _importAssignment(CanvasAssignment assignment) async {
    final box = Hive.box<Task>('tasks');
    final newTask = Task(
      id: assignment.id,
      title: assignment.name,
      description: "Imported from Canvas",
      date: assignment.dueDate,
      source: "canvas",
    );
    // Capture messenger before awaiting to avoid using BuildContext
    // across async gaps.
    final messenger = ScaffoldMessenger.of(context);
    await box.put(newTask.id, newTask);
    setState(() {
      _importedAssignmentIds.add(assignment.id);
    });
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Imported "${assignment.name}" to planner!')),
    );
  }

  Future<void> _fetchAssignmentsForCourse(String courseId) async {
    if (_token == null ||
        _canvasDomain == null ||
        _assignmentsByCourse.containsKey(courseId)) {
      return;
    }

    setState(() => _isCourseLoading[courseId] = true);
    try {
      final assignments = await _canvasService.fetchAssignments(
          _canvasDomain!, _token!, courseId);
      setState(() => _assignmentsByCourse[courseId] = assignments);
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('Error fetching assignments: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCourseLoading[courseId] = false);
    }
  }

  Future<void> _disconnect() async {
    await _canvasService.disconnect();
    setState(() {
      _status = SyncStatus.disconnected;
      _token = null;
      _canvasDomain = null;
      _courses = [];
      _assignmentsByCourse = {};
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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

    return Container(
      decoration: backgroundDecoration,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Canvas Sync'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_status == SyncStatus.connected)
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Disconnect from Canvas',
                onPressed: _disconnect,
              ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case SyncStatus.connecting:
        return const Center(
            key: ValueKey('connecting'),
            child: CircularProgressIndicator(
              color: Colors.white,
            ));
      case SyncStatus.disconnected:
        return _buildCenteredMessage(
          key: const ValueKey('disconnected'),
          icon: Icons.link_off,
          title: 'Not Connected',
          message:
              "Enter your school's Canvas domain to connect (e.g., canvas.instructure.com).",
          buttonText: 'Connect to Canvas',
          onPressed: _loginAndFetchCourses,
          customContent: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: TextField(
              controller: _domainController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Canvas Domain',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black.withAlpha((0.2 * 255).round()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      case SyncStatus.error:
        return _buildCenteredMessage(
          key: const ValueKey('error'),
          icon: Icons.error_outline,
          title: 'Connection Failed',
          message: _errorMessage ?? 'An unknown error occurred.',
          buttonText: 'Try Again',
          onPressed: _loginAndFetchCourses,
        );
      case SyncStatus.connected:
        return _buildConnectedView();
    }
  }

  Widget _buildCenteredMessage({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
    Widget? customContent,
  }) {
    return Center(
      key: key,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withAlpha((0.2 * 255).round())),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70)),
                    if (customContent != null) customContent,
                    const SizedBox(height: 24),
                    ElevatedButton(
                        onPressed: onPressed, child: Text(buttonText)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectedView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Connected to: $_canvasDomain',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70)),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('connected'),
            itemCount: _courses.length,
            itemBuilder: (context, index) {
              final course = _courses[index];
              final assignments = _assignmentsByCourse[course.id] ?? [];
              final isLoading = _isCourseLoading[course.id] ?? false;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withAlpha((0.2 * 255).round())),
                      ),
                      child: ExpansionTile(
                        leading: const Icon(Icons.class_outlined,
                            color: Colors.white),
                        title: Text(course.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        iconColor: Colors.white,
                        collapsedIconColor: Colors.white70,
                        onExpansionChanged: (isExpanding) {
                          if (isExpanding) {
                            _fetchAssignmentsForCourse(course.id);
                          }
                        },
                        children: [
                          if (isLoading)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white)),
                            ),
                          if (!isLoading && assignments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                  'No assignments found for this course.',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                          ...assignments.map((assignment) {
                            final isImported =
                                _importedAssignmentIds.contains(assignment.id);
                            return ListTile(
                              title: Text(assignment.name,
                                  style: const TextStyle(color: Colors.white)),
                              subtitle: Text(
                                  'Due: ${DateFormat.yMMMd().add_jm().format(assignment.dueDate)}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              trailing: isImported
                                  ? Chip(
                                      avatar: Icon(Icons.check,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                      label: const Text('Imported'),
                                      backgroundColor: Colors.white
                                          .withAlpha((0.8 * 255).round()),
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : ElevatedButton(
                                      onPressed: () =>
                                          _importAssignment(assignment),
                                      child: const Text('Import'),
                                    ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
