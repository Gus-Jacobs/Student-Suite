import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io'; // For File
import 'package:flutter/foundation.dart' show kIsWeb; // For kIsWeb check
import 'dart:typed_data'; // For Uint8List
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'package:student_suite/models/ai_interview_session.dart';
import 'package:student_suite/models/hive_chat_message.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/services/ai_service.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import '../providers/theme_provider.dart';
import '../models/tutorial_step.dart';
import '../widgets/upgrade_dialog.dart';
import 'dart:ui'; // For ImageFilter

class AIInterviewerScreen extends StatefulWidget {
  final AIInterviewSession? sessionToResume;
  const AIInterviewerScreen({super.key, this.sessionToResume});

  @override
  State<AIInterviewerScreen> createState() => _AIInterviewerScreenState();
}

enum ScreenView { list, setup, interviewing }

class _AIInterviewerScreenState extends State<AIInterviewerScreen>
    with TutorialSupport<AIInterviewerScreen> {
  final AiService _aiService = AiService();
  ScreenView _screenView = ScreenView.list;
  AIInterviewSession? _activeSession;
  final TextEditingController _jobDescController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _resumeText;
  String? _resumeFileName;
  bool _isLoading = false;

  @override
  String get tutorialKey => 'ai_interviewer';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.work_outline,
            title: 'Provide Context',
            description:
                'Paste the job description and upload your resume. The more context you give the AI, the better the mock interview will be.'),
        TutorialStep(
            icon: Icons.question_answer_outlined,
            title: 'Answer the Questions',
            description:
                'The AI will ask you questions one by one. Take your time and answer as you would in a real interview.'),
        TutorialStep(
            icon: Icons.rate_review_outlined,
            title: 'Get Feedback',
            description:
                'When the interview is over, the AI will provide detailed, constructive feedback on your performance.'),
      ];

  @override
  void dispose() {
    _jobDescController.dispose();
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure the first build is complete
    // before calling setState to change the view or showing a dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sessionToResume != null) {
        _resumeSession(widget.sessionToResume!);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickResume() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final platformFile = result.files.single;
        setState(() => _isLoading = true);

        // Read bytes differently for web vs. mobile/desktop
        Uint8List? fileBytes;
        if (kIsWeb) {
          // On web, the bytes are directly available in the PlatformFile object.
          fileBytes = platformFile.bytes;
        } else {
          // On mobile/desktop, we get a path and read the file.
          if (platformFile.path == null) {
            throw Exception("File path is null on a non-web platform.");
          }
          fileBytes = await File(platformFile.path!).readAsBytes();
        }

        if (fileBytes == null) throw Exception("Could not read file bytes.");

        final syncfusion_pdf.PdfDocument document =
            syncfusion_pdf.PdfDocument(inputBytes: fileBytes);
        final String text =
            syncfusion_pdf.PdfTextExtractor(document).extractText();
        document.dispose();
        if (!mounted) return;
        setState(() {
          _resumeText = text;
          _resumeFileName = platformFile.name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, "Failed to read resume: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startNewInterview() async {
    final subscription =
        Provider.of<SubscriptionProvider>(context, listen: false);
    if (!subscription.isPro) {
      showUpgradeDialog(context);
      return;
    }

    if (_jobDescController.text.trim().isEmpty) {
      showErrorDialog(context, "Please provide a job description.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final newSession = AIInterviewSession.create(
      jobDescription: _jobDescController.text.trim(),
      resumeText: _resumeText,
    );

    final box = context.read<AuthProvider>().aiInterviewSessionsBox;
    await box.put(newSession.id, newSession);

    setState(() {
      _activeSession = newSession;
    });

    await _getAiResponse();

    if (!mounted) return;
    setState(() {
      _screenView = ScreenView.interviewing;
      _isLoading = false;
    });
  }

  Future<void> _submitAnswer() async {
    if (_answerController.text.trim().isEmpty ||
        _isLoading ||
        _activeSession == null) {
      return;
    }
    final answer = _answerController.text.trim();
    _answerController.clear();

    setState(() {
      _activeSession!.messages
          .add(HiveChatMessage(role: 'user', content: answer));
    });
    await _activeSession!.save();
    _scrollToBottom();

    // Check for safe words
    final lowerCaseAnswer = answer.toLowerCase();
    if (lowerCaseAnswer == 'stop interview' || lowerCaseAnswer == 'stop') {
      await _endInterview();
      return;
    }

    // Get AI's next question
    await _getAiResponse();
  }

  Future<void> _getAiResponse() async {
    setState(() => _isLoading = true);
    _scrollToBottom();

    if (_activeSession == null) {
      setState(() => _isLoading = false);
      return;
    }

    final history = _activeSession!.messages
        .map((m) => ChatMessage(role: m.role, content: m.content))
        .toList();

    try {
      final response = await _aiService.getInterviewerResponse(
        history: history, // Pass the converted history
        jobDescription: _jobDescController.text,
        resumeText: _resumeText,
      );

      if (response == '[END_INTERVIEW]') {
        await _endInterview();
      } else {
        if (!mounted) return;
        setState(() {
          _activeSession!.messages
              .add(HiveChatMessage(role: 'model', content: response));
        });
        await _activeSession!.save();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, "The AI Interviewer had a problem: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _endInterview() async {
    setState(() {
      _isLoading = true;
    });

    if (_activeSession == null) return;

    final history = _activeSession!.messages
        .map((m) => ChatMessage(role: m.role, content: m.content))
        .toList();

    try {
      final feedback = await _aiService.getInterviewFeedback(
        history: history, // Pass converted history
        jobDescription: _activeSession!.jobDescription,
        resumeText: _activeSession!.resumeText,
      );
      if (!mounted) return;
      setState(() {
        _activeSession!.feedback = feedback;
      });
      await _activeSession!.save();
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, "Failed to get feedback: $e");
        // Go back to setup on feedback error
        setState(() => _screenView = ScreenView.setup);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resumeSession(AIInterviewSession session) {
    setState(() {
      _activeSession = session;
      _screenView = ScreenView.interviewing;
      _jobDescController.text = session.jobDescription;
      _resumeText = session.resumeText;
    });
    _scrollToBottom();
  }

  Future<void> _deleteSession(AIInterviewSession session) async {
    await session.delete();
    if (_activeSession?.id == session.id) {
      _resetToListView();
    }
  }

  void _resetToListView() {
    setState(() {
      _screenView = ScreenView.list;
      _activeSession = null;
      _jobDescController.clear();
      _resumeText = null;
      _resumeFileName = null;
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
              Colors.black.withAlpha((0.5 * 255).round()), BlendMode.darken),
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
          title: Text(_getAppBarTitle()),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _screenView != ScreenView.list
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: _resetToListView,
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: showTutorialDialog,
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _buildBody(),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_screenView) {
      case ScreenView.list:
        return 'Interview Sessions';
      case ScreenView.setup:
        return 'AI Interviewer';
      case ScreenView.interviewing:
        return _activeSession?.jobDescription.split('\n').first ??
            'Mock Interview';
    }
  }

  Widget _buildBody() {
    switch (_screenView) {
      case ScreenView.list:
        return _buildListView();
      case ScreenView.setup:
        return _buildSetupView();
      case ScreenView.interviewing:
        return _buildInterviewView();
    }
  }

  Widget _buildListView() {
    return ValueListenableBuilder<Box<AIInterviewSession>>(
      key: const ValueKey('list'),
      valueListenable:
          context.read<AuthProvider>().aiInterviewSessionsBox.listenable(),
      builder: (context, box, _) {
        final sessions = box.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Column(
          children: [
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.question_answer_outlined,
                                size: 80,
                                color: Colors.white
                                    .withAlpha((0.7 * 255).round())),
                            const SizedBox(height: 16),
                            Text(
                              'No interviews yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap 'Start New Interview' to begin.",
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        return _buildSessionCard(sessions[index]);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Start New Interview'),
                onPressed: () => setState(() => _screenView = ScreenView.setup),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSetupView() {
    return ListView(
      key: const ValueKey('setup'),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _jobDescController,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Paste Job Description',
            hintText: 'The more detail, the better...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickResume,
          icon: const Icon(Icons.upload_file),
          label: Text(_resumeFileName ?? 'Upload Resume (Optional)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _startNewInterview,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ))
              : const Icon(Icons.smart_toy_outlined),
          label: Text(_isLoading ? 'Starting...' : 'Start Interview'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildInterviewView() {
    if (_activeSession == null) {
      return const Center(child: Text('Error: No active session.'));
    }
    // If feedback exists, show it.
    if (_activeSession!.feedback != null) {
      return _buildFeedbackView();
    }
    return Column(
      key: ValueKey(_activeSession!.id),
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            itemCount: _activeSession!.messages.length,
            itemBuilder: (context, index) {
              final message = _activeSession!.messages[index];
              return _MessageBubble(
                content: message.content,
                isFromUser: message.role == 'user',
              );
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        _buildAnswerInput(),
      ],
    );
  }

  Widget _buildFeedbackView() {
    return SingleChildScrollView(
      key: const ValueKey('feedback'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            color: Colors.white.withAlpha((0.9 * 255).round()),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MarkdownBody(
                data: _activeSession!.feedback!,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                        p: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.black87)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetToListView,
            child: const Text('Back to Sessions'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerInput() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentTheme = themeProvider.currentTheme;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: currentTheme.glassGradient,
              color: currentTheme.glassGradient == null
                  ? Colors.black.withAlpha((0.2 * 255).round())
                  : null,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                  color: Colors.white.withAlpha((0.2 * 255).round())),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(
                      hintText: 'Type your answer...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _submitAnswer(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _submitAnswer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(AIInterviewSession session) {
    return Card(
      color: Colors.white.withAlpha((0.1 * 255).round()),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
            session.feedback != null
                ? Icons.rate_review_outlined
                : Icons.question_answer_outlined,
            color: Colors.white70),
        title: Text(session.jobDescription.split('\n').first,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(DateFormat.yMMMd().add_jm().format(session.createdAt)),
        onTap: () => _resumeSession(session),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteSession(session),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isFromUser;

  const _MessageBubble({required this.content, required this.isFromUser});

  @override
  Widget build(BuildContext context) {
    final alignment =
        isFromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = isFromUser
        ? Theme.of(context).colorScheme.primary.withAlpha((0.5 * 255).round())
        : Colors.black.withAlpha((0.3 * 255).round());

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                        p: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.white))),
          ),
        ],
      ),
    );
  }
}
