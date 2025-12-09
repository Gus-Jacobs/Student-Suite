import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/models/tutorial_step.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/screens/subject_editor_screen.dart';

class SubjectManagerScreen extends StatefulWidget {
  const SubjectManagerScreen({super.key});

  @override
  State<SubjectManagerScreen> createState() => _SubjectManagerScreenState();
}

class _SubjectManagerScreenState extends State<SubjectManagerScreen>
    with TutorialSupport<SubjectManagerScreen> {
  final _nameController = TextEditingController();

  @override
  String get tutorialKey => 'subjects';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.library_books_outlined,
            title: 'What are Subjects?',
            description:
                'Subjects are containers for your course materials, like a syllabus, notes, or textbook chapters.'),
        TutorialStep(
            icon: Icons.add_circle_outline,
            title: 'Create a Subject',
            description:
                "Tap the '+' button to create a new subject for one of your courses."),
        TutorialStep(
            icon: Icons.psychology_outlined,
            title: 'Provide AI Context',
            description:
                'Once created, you can add content to a subject. This content can then be used by AI tools like the AI Teacher and Flashcard Generator to give them specific context for your class.'),
      ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _addSubject(String name) async {
    if (name.trim().isEmpty) return;
    final box = context.read<AuthProvider>().subjectsBox;
    if (box.values.any((s) => s.name == name.trim())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('A subject with the name "$name" already exists.')),
        );
      }
      return;
    }
    final newSubject = Subject.create(name: name.trim());
    await box.put(newSubject.id, newSubject);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubjectEditorScreen(subjectId: newSubject.id),
        ),
      );
    }
  }

  void _showAddSubjectDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Subject'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Subject Name'),
          autofocus: true,
          onSubmitted: (_) {
            Navigator.of(ctx).pop();
            _addSubject(_nameController.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _addSubject(_nameController.text);
            },
            child: const Text('Create & Edit'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Subject subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text(
            'Are you sure you want to delete the "${subject.name}" subject and all its content? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              subject.delete();
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
          title: const Text('AI Context Subjects'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: showTutorialDialog,
            ),
          ],
        ),
        body: ValueListenableBuilder<Box<Subject>>(
          valueListenable:
              context.read<AuthProvider>().subjectsBox.listenable(),
          builder: (context, box, _) {
            final subjects = box.values.toList()
              ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

            if (subjects.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined,
                          size: 80,
                          color: Colors.white.withAlpha((0.7 * 255).round())),
                      const SizedBox(height: 16),
                      Text(
                        'No Subjects Yet',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap '+' to create a subject. You can add notes, documents, and other text to give the AI context for tasks.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.topic_outlined),
                    title: Text(subject.name),
                    subtitle: Text(
                        'Updated: ${DateFormat.yMMMd().add_jm().format(subject.lastUpdated)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () => _showDeleteConfirmDialog(subject),
                    ),
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SubjectEditorScreen(subjectId: subject.id),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddSubjectDialog,
          tooltip: 'Create Subject',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
