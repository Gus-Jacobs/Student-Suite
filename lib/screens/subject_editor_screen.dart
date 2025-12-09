import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:student_suite/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/models/subject.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import 'package:student_suite/widgets/glass_section.dart'; // Assuming you have this widget

class SubjectEditorScreen extends StatefulWidget {
  final String subjectId;
  const SubjectEditorScreen({super.key, required this.subjectId});

  @override
  State<SubjectEditorScreen> createState() => _SubjectEditorScreenState();
}

class _SubjectEditorScreenState extends State<SubjectEditorScreen> {
  late Subject _subject;
  bool _isLoading = true;
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();

  // Local state for attachments
  List<String> _attachedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadSubject();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _loadSubject() {
    final box = context.read<AuthProvider>().subjectsBox;
    final subject = box.get(widget.subjectId);
    if (subject != null) {
      setState(() {
        _subject = subject;
        _nameController.text = _subject.name;
        _contentController.text = _subject.content;
        // Load existing files
        _attachedFiles = List.from(_subject.filePaths);
        _isLoading = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveSubject() async {
    if (_nameController.text.trim().isEmpty) {
      showErrorDialog(context, 'Subject name cannot be empty.');
      return;
    }
    setState(() {
      _subject.name = _nameController.text.trim();
      _subject.content = _contentController.text.trim();
      _subject.filePaths = _attachedFiles; // Save the list
      _subject.lastUpdated = DateTime.now();
    });
    await _subject.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject saved!')),
      );
    }
  }

  Future<void> _attachFile() async {
    // 1. Check for Web FIRST
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Web Limit'),
          content: const Text(
            'File attachments are only available on the mobile app. '
            'For web, please copy and paste the text content directly into the editor.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // 2. Existing Mobile Logic
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx', 'ppt', 'pptx'],
      );

      if (result != null) {
        final path = result.files.single.path;
        if (path != null) {
          setState(() {
            _attachedFiles.add(path);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Failed to attach file: $e');
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        if (_contentController.text.isNotEmpty) {
          _contentController.text += '\n\n';
        }
        _contentController.text += clipboardData.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasted content.')),
        );
      }
    }
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
          title: _isLoading
              ? const Text('Loading...')
              : TextField(
                  controller: _nameController,
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Subject Name',
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                  onSubmitted: (_) => _saveSubject(),
                ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveSubject,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- ATTACHMENTS SECTION --
                    if (_attachedFiles.isNotEmpty) ...[
                      const Text("Attachments:",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachedFiles.length,
                          itemBuilder: (ctx, index) {
                            final path = _attachedFiles[index];
                            final name =
                                path.split(Platform.pathSeparator).last;
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attach_file,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Text(name,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 16, color: Colors.redAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => setState(
                                        () => _attachedFiles.removeAt(index)),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // -- CONTENT EDITOR --
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type specific context notes here...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor:
                              Colors.black.withAlpha((0.2 * 255).round()),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _attachFile,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Attach File'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Paste Text'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
