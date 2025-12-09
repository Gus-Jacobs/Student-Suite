import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/saved_document.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/screens/resume_editor_screen.dart';
import 'package:student_suite/screens/cover_letter_editor_screen.dart';

class SavedDocumentsScreen extends StatelessWidget {
  const SavedDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context).currentTheme;

    final int initialIndex =
        (ModalRoute.of(context)?.settings.arguments as int?) ?? 0;

    // Background setup
    BoxDecoration backgroundDecoration;
    if (theme.imageAssetPath != null) {
      backgroundDecoration = BoxDecoration(
        image: DecorationImage(
          image: AssetImage(theme.imageAssetPath!),
          fit: BoxFit.cover,
          colorFilter:
              ColorFilter.mode(Colors.black.withAlpha(128), BlendMode.darken),
        ),
      );
    } else {
      backgroundDecoration = BoxDecoration(gradient: theme.gradient);
    }

    return Container(
      decoration: backgroundDecoration,
      child: DefaultTabController(
        length: 2,
        initialIndex: initialIndex, // <--- ADD THIS LINE
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text("My Documents"),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              indicatorColor: theme.primaryAccent,
              tabs: const [
                Tab(text: "Resumes"),
                Tab(text: "Cover Letters"),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildDocumentList(context, auth.savedDocumentsBox, 'resume'),
              _buildDocumentList(
                  context, auth.savedDocumentsBox, 'cover_letter'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentList(
      BuildContext context, Box<SavedDocument> box, String type) {
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<SavedDocument> box, _) {
        // Filter by type (resume vs cover letter)
        final docs = box.values.where((doc) => doc.type == type).toList();
        // Sort by newest first
        docs.sort((a, b) => b.lastModified.compareTo(a.lastModified));

        if (docs.isEmpty) {
          return Center(
            child: Text(
              "No saved ${type.replaceAll('_', ' ')}s yet.",
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, index) {
            final doc = docs[index];
            return Card(
              color: Colors.white.withAlpha(20),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withAlpha(30))),
              child: ListTile(
                title: Text(doc.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Last edited: ${DateFormat.yMMMd().format(doc.lastModified)}",
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => doc.delete(),
                ),
                onTap: () => _openDocument(context, doc),
              ),
            );
          },
        );
      },
    );
  }

  void _openDocument(BuildContext context, SavedDocument doc) {
    if (doc.type == 'resume') {
      // For resumes, we might need to separate contact info from the main map
      // depending on how your ResumeEditor expects it.
      // Based on your code, ResumeEditor expects 'contact' inside initialContent
      // OR passed separately. We'll pass the whole blob.

      final content = Map<String, dynamic>.from(doc.content);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResumeEditorScreen(
            initialContent: content,
            contactInfo: Map<String, String>.from(content['contact'] ?? {}),
            templateName: 'Saved',
            documentId:
                doc.id, // Pass ID to enable "Update" instead of "Create New"
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CoverLetterEditorScreen(
            initialContent: Map<String, dynamic>.from(doc.content),
            userName: doc.content['user_name'] ?? '',
            templateName: 'Saved',
            documentId: doc.id, // Pass ID
          ),
        ),
      );
    }
  }
}
