import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/services/ai_service.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import 'package:student_suite/widgets/upgrade_dialog.dart';
import 'package:uuid/uuid.dart';
import '../providers/theme_provider.dart';
import '../models/tutorial_step.dart';
import 'dart:ui'; // For ImageFilter
import '../models/subject.dart';
import '../models/ai_teacher_session.dart';
import '../models/hive_chat_message.dart';

class AITeacherScreen extends StatefulWidget {
  final AITeacherSession? sessionToResume;

  const AITeacherScreen({super.key, this.sessionToResume});

  @override
  State<AITeacherScreen> createState() => _AITeacherScreenState();
}

enum ScreenView { list, setup, teaching }

class _AITeacherScreenState extends State<AITeacherScreen>
    with TutorialSupport<AITeacherScreen> {
  final AiService _aiService = AiService();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Uuid _uuid = const Uuid();

  ScreenView _screenView = ScreenView.list;
  AITeacherSession? _activeSession;
  bool _isLoading = false;
  bool _showContinueButton = false;
  List<Subject> _subjects = [];
  Subject? _selectedSubject;

  @override
  String get tutorialKey => 'ai_teacher';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.topic_outlined,
            title: 'Start a Lesson',
            description:
                'Begin by telling the AI what topic you want to learn about. You can also provide context, like a syllabus or textbook chapter.'),
        TutorialStep(
            icon: Icons.question_answer_outlined,
            title: 'Ask Questions',
            description:
                'Engage with the AI just like a real tutor. Ask for clarifications, examples, or to explain things in a different way.'),
        TutorialStep(
            icon: Icons.history_edu_outlined,
            title: 'Resume Anytime',
            description:
                'All your lessons are saved. You can come back later and pick up right where you left off.'),
      ];

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure the first build is complete
    // before calling setState to change the view or showing a dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sessionToResume != null) {
        _resumeSession(widget.sessionToResume!);
      }
      final box = context.read<AuthProvider>().subjectsBox;
      setState(() => _subjects = box.values.toList());
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _promptController.dispose();
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  // --- Session Management ---

  Future<void> _startLesson() async {
    final subscription =
        Provider.of<SubscriptionProvider>(context, listen: false);
    if (!subscription.isPro) {
      showUpgradeDialog(context);
      return;
    }

    if (_topicController.text.trim().isEmpty) {
      showErrorDialog(context, 'Please enter a topic to start the lesson.');
      return;
    }

    final topic = _topicController.text.trim();
    final newSession = AITeacherSession(
      id: _uuid.v4(),
      topic: topic,
      createdAt: DateTime.now(),
      messages: [],
    );

    String contextPrompt = _promptController.text.trim();
    if (_selectedSubject != null) {
      contextPrompt += '\n\nCourse Context:\n${_selectedSubject!.content}';
    }

    final initialPrompt = 'Please start teaching me about "$topic". '
        'Here is some additional context for the lesson: $contextPrompt';

    newSession.messages
        .add(HiveChatMessage(role: 'user', content: initialPrompt));

    final box = context.read<AuthProvider>().aiTeacherSessionsBox;
    await box.put(newSession.id, newSession);

    setState(() {
      _activeSession = newSession;
      _screenView = ScreenView.teaching;
      _isLoading = true;
    });

    _getAiResponse();
  }

  Future<void> _resumeSession(AITeacherSession session) async {
    final lastMessage =
        session.messages.isNotEmpty ? session.messages.last : null;
    final shouldShowContinue = lastMessage?.role == 'model' &&
        lastMessage?.content.endsWith('[CONTINUE_PLACEHOLDER]') == true;

    if (shouldShowContinue) {
      lastMessage!.content =
          lastMessage.content.replaceAll('[CONTINUE_PLACEHOLDER]', '').trim();
      await session.save();
    }

    setState(() {
      _activeSession = session;
      _screenView = ScreenView.teaching;
      _showContinueButton = shouldShowContinue;
    });
    _scrollToBottom();
  }

  Future<void> _deleteSession(AITeacherSession session) async {
    await session.delete();
    // If the deleted session was the active one, go back to the list
    if (_activeSession?.id == session.id) {
      setState(() {
        _activeSession = null;
        _screenView = ScreenView.list;
      });
    }
  }

  // --- AI Interaction ---

  List<ChatMessage> _getHistoryForApi() {
    if (_activeSession == null) return [];
    return _activeSession!.messages
        .map((m) => ChatMessage(role: m.role, content: m.content))
        .toList();
  }

  Future<void> _askQuestion() async {
    if (_questionController.text.trim().isEmpty || _activeSession == null) {
      return;
    }

    final question = _questionController.text.trim();
    _questionController.clear();

    setState(() {
      _isLoading = true;
      _showContinueButton = false;
      _activeSession!.messages
          .add(HiveChatMessage(role: 'user', content: question));
    });
    await _activeSession!.save();

    _getAiResponse();
  }

  Future<void> _continueLesson() async {
    if (_activeSession == null) return;
    setState(() {
      _isLoading = true;
      _showContinueButton = false;
      _activeSession!.messages
          .add(HiveChatMessage(role: 'user', content: 'Please continue.'));
    });
    await _activeSession!.save();
    _getAiResponse();
  }

  Future<void> _getAiResponse() async {
    if (_activeSession == null) return;
    _scrollToBottom();
    try {
      final response =
          await _aiService.getTeacherResponse(history: _getHistoryForApi());
      String responseText = response;

      bool shouldShowContinue = false;
      if (response.endsWith('[CONTINUE]')) {
        // We store a placeholder and remove it when displaying, so we can know
        // on session resume whether to show the continue button.
        responseText =
            '${response.replaceAll('[CONTINUE]', '').trim()}[CONTINUE_PLACEHOLDER]';
        shouldShowContinue = true;
      }

      setState(() {
        _activeSession!.messages
            .add(HiveChatMessage(role: 'model', content: responseText));
        _showContinueButton = shouldShowContinue;
      });
      await _activeSession!.save();
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'The AI Teacher had a problem: $e');
        // Add a message to history to show the error
        setState(() {
          _activeSession!.messages.add(HiveChatMessage(
              role: 'model',
              content:
                  'I seem to have encountered an error. Please try again.'));
        });
        await _activeSession!.save();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  // --- UI Building ---

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
          title: Text(_getAppBarTitle()),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _screenView != ScreenView.list
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () {
                    setState(() {
                      _screenView = ScreenView.list;
                      _activeSession = null;
                      _topicController.clear();
                      _promptController.clear();
                    });
                  },
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
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_screenView) {
      case ScreenView.list:
        return 'AI Teacher Sessions';
      case ScreenView.setup:
        return 'Start New Lesson';
      case ScreenView.teaching:
        return _activeSession?.topic ?? 'AI Teacher';
    }
  }

  Widget _buildCurrentView() {
    switch (_screenView) {
      case ScreenView.list:
        return _buildListView();
      case ScreenView.setup:
        return _buildSetupView();
      case ScreenView.teaching:
        return _buildTeachingView();
    }
  }

  Widget _buildListView() {
    return ValueListenableBuilder<Box<AITeacherSession>>(
      key: const ValueKey('list'),
      valueListenable:
          context.read<AuthProvider>().aiTeacherSessionsBox.listenable(),
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
                            Icon(Icons.school_outlined,
                                size: 80,
                                color: Colors.white
                                    .withAlpha((0.7 * 255).round())),
                            const SizedBox(height: 16),
                            Text(
                              'No lessons yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap 'Start New Lesson' to begin.",
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
                        final session = sessions[index];
                        return Card(
                          color: Colors.white.withAlpha((0.1 * 255).round()),
                          child: ListTile(
                            leading: const Icon(Icons.history_edu_outlined,
                                color: Colors.white70),
                            title: Text(session.topic,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                                DateFormat.yMMMd()
                                    .add_jm()
                                    .format(session.createdAt),
                                style: const TextStyle(color: Colors.white70)),
                            onTap: () => _resumeSession(session),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _deleteSession(session),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Start New Lesson'),
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
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.smart_toy_outlined, size: 80, color: Colors.white70),
        const SizedBox(height: 16),
        Text(
          'Ready to Learn?',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell the AI Teacher what you want to learn about. You can also provide context like a syllabus or test outline.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 32),
        if (_subjects.isNotEmpty) ...[
          DropdownButtonFormField<Subject?>(
            value: _selectedSubject,
            items: [
              const DropdownMenuItem<Subject?>(
                value: null,
                child: Text('None (General Topic)'),
              ),
              ..._subjects.map((subject) {
                return DropdownMenuItem<Subject>(
                  value: subject,
                  child: Text(subject.name),
                );
              }),
            ],
            onChanged: (Subject? newValue) {
              setState(() {
                _selectedSubject = newValue;
              });
            },
            decoration: InputDecoration(
              labelText: 'Select Course (Optional)',
              filled: true,
              fillColor: Colors.black.withAlpha((0.2 * 255).round()),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _topicController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Main Topic',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'e.g., "The Ethics of AI"',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black.withAlpha((0.2 * 255).round()),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _promptController,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Optional Context',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText:
                'e.g., "Focus on algorithmic bias and data privacy. The test is next week."',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black.withAlpha((0.2 * 255).round()),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text("Let's Begin!"),
          onPressed: _isLoading ? null : _startLesson,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTeachingView() {
    if (_activeSession == null) {
      return const Center(
          child: Text('Error: No active session.',
              style: TextStyle(color: Colors.white)));
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
                content:
                    message.content.replaceAll('[CONTINUE_PLACEHOLDER]', ''),
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
        if (_showContinueButton && !_isLoading)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _continueLesson,
              child: const Text('Continue Lesson'),
            ),
          ),
        _buildQuestionInput(),
      ],
    );
  }

  Widget _buildQuestionInput() {
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
                    controller: _questionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Raise hand (ask a question)...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _askQuestion(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _isLoading ? null : _askQuestion,
                ),
              ],
            ),
          ),
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
    const textColor = Colors.white;

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
            child: isFromUser
                ? Text(content, style: const TextStyle(color: textColor))
                : MarkdownBody(
                    data: content,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                            p: const TextStyle(color: textColor, fontSize: 16))),
          ),
        ],
      ),
    );
  }
}
