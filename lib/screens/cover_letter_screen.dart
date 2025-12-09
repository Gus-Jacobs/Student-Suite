// lib/screens/cover_letter_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/models/tutorial_step.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/screens/cover_letter_editor_screen.dart';
import 'package:student_suite/services/ai_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/upgrade_dialog.dart';
import '../widgets/error_dialog.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/template_preview_card.dart';

class CoverLetterScreen extends StatefulWidget {
  const CoverLetterScreen({super.key});
  @override
  State<CoverLetterScreen> createState() => _CoverLetterScreenState();
}

class _CoverLetterScreenState extends State<CoverLetterScreen>
    with TutorialSupport<CoverLetterScreen>, SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _managerController = TextEditingController();
  final _jobDescController = TextEditingController();
  final AiService _aiService = AiService();

  bool _isLoading = false;
  String _selectedTemplate = 'Classic';

  // Animation for template selection
  late final AnimationController _selectorAnimController;

  @override
  String get tutorialKey => 'cover_letter';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
            icon: Icons.business_center_outlined,
            title: 'Provide Job Details',
            description:
                'Enter your name, the company, and paste the job description. The AI uses this to tailor your letter.'),
        TutorialStep(
            icon: Icons.auto_fix_high,
            title: 'Generate with AI',
            description:
                'Our AI will write a professional, three-paragraph cover letter based on the info you provided.'),
      ];

  @override
  void initState() {
    super.initState();

    // Init animation for template selection
    _selectorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Keep controller initialized for template animations; specific CurvedAnimation
    // was removed as it was not used.

    // Pre-fill the user's name from their profile for convenience.
    // It's safe to use context.read in initState (widget is mounted).
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.displayName;
  }

  @override
  void dispose() {
    _selectorAnimController.dispose();
    _nameController.dispose();
    _companyController.dispose();
    _managerController.dispose();
    _jobDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = themeProvider.currentTheme;
    final subscription = Provider.of<SubscriptionProvider>(context);
    final isPro = subscription.isPro;

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
          title: const Text('Cover Letter Generator'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Open Saved Letters',
              onPressed: () => Navigator.pushNamed(
                context,
                '/saved_documents',
                arguments: 1,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: showTutorialDialog,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassTextField(
                controller: _nameController,
                label: 'Your Name',
                icon: Icons.person_outline,
                isRequired: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              GlassTextField(
                controller: _companyController,
                label: 'Company Name',
                icon: Icons.business_outlined,
                isRequired: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              GlassTextField(
                controller: _managerController,
                label: 'Hiring Manager (Optional)',
                icon: Icons.person_search_outlined,
                isRequired: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              GlassTextField(
                controller: _jobDescController,
                label: 'Paste Job Description',
                maxLines: 6,
                icon: Icons.description_outlined,
                isRequired: true,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 24),

              // Template header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select a Template',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  // Small helper
                  IconButton(
                    tooltip: 'Preview templates',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () {
                      _showTemplatesQuickHelp();
                    },
                  )
                ],
              ),
              const SizedBox(height: 8),

              // Template selector: horizontal list with scale animation and lock overlay for Pro templates
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _templateList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final tpl = _templateList[index];
                    final isSelected = tpl.name == _selectedTemplate;
                    final isLocked = tpl.isPro && !isPro;

                    return GestureDetector(
                      onTap: () {
                        if (isLocked) {
                          // Prompt upgrade
                          showUpgradeDialog(context);
                          return;
                        }
                        setState(() {
                          _selectedTemplate = tpl.name;
                        });
                        // quick tap animation
                        _selectorAnimController.forward(from: 0.0);
                      },
                      onLongPress: () {
                        // preview HTML template or show a quick dialog; here we show a quick preview dialog with description
                        _showTemplatePreview(tpl);
                      },
                      child: AnimatedScale(
                        scale: isSelected ? 1.03 : 1.0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        child: Opacity(
                          opacity: isLocked ? 0.6 : 1.0,
                          child: TemplatePreviewCard(
                            templateName: tpl.name,
                            icon: tpl.icon,
                            isSelected: isSelected,
                            onTap: () {
                              // same behavior as outer tap — keep for cards that handle taps internally
                              if (isLocked) {
                                showUpgradeDialog(context);
                                return;
                              }
                              setState(() => _selectedTemplate = tpl.name);
                              _selectorAnimController.forward(from: 0.0);
                            },
                            // template card can optionally show a 'PRO' tag if locked
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Generate button
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isLoading ? 'Generating...' : 'Generate with AI'),
                onPressed: _isLoading ? null : () => _onGeneratePressed(isPro),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 12),

              // Non-pro hint
              if (!isPro)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pro required to generate personalized cover letters. Tap Upgrade to unlock.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => showUpgradeDialog(context),
                        child: const Text('Upgrade'),
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onGeneratePressed(bool isPro) async {
    if (!isPro) {
      showUpgradeDialog(context);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      // show helpful error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill required fields before generating.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await _generateLetter();
  }

  Future<void> _generateLetter() async {
    setState(() => _isLoading = true);

    try {
      final content = await _aiService.generateCoverLetter(
        userName: _nameController.text.trim(),
        companyName: _companyController.text.trim(),
        hiringManager: _managerController.text.trim(),
        jobDescription: _jobDescController.text.trim(),
        templateStyle: _selectedTemplate,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CoverLetterEditorScreen(
            initialContent: content,
            userName: _nameController.text.trim(),
            templateName: _selectedTemplate,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('CoverLetterScreen: generate error: $e\n$st');
      if (mounted) {
        showErrorDialog(context, "Failed to generate cover letter: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTemplatePreview(_TemplateInfo tpl) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('${tpl.name} Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tpl.shortDescription),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (tpl.isPro)
                    Chip(
                      label: const Text('PRO'),
                      backgroundColor: Colors.amber.shade700,
                    ),
                  Chip(label: Text(tpl.exampleTone)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close')),
            if (tpl.isPro &&
                !Provider.of<SubscriptionProvider>(context, listen: false)
                    .isPro)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  showUpgradeDialog(context);
                },
                child: const Text('Upgrade'),
              ),
          ],
        );
      },
    );
  }

  void _showTemplatesQuickHelp() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Template Guide'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.menu_book_outlined),
                title: Text('Classic'),
                subtitle:
                    Text('Formal, conservative — great for corporate roles.'),
              ),
              ListTile(
                leading: Icon(Icons.style_outlined),
                title: Text('Modern'),
                subtitle: Text(
                    'Clean layout with subtle accents — good for startups and design-minded roles.'),
              ),
              ListTile(
                leading: Icon(Icons.auto_awesome),
                title: Text('Creative'),
                subtitle: Text(
                    'Bold, colorful header and layout — ideal for creative fields.'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close')),
          ],
        );
      },
    );
  }

  // Local template model + list
  final List<_TemplateInfo> _templateList = const [
    _TemplateInfo(
      name: 'Classic',
      icon: Icons.menu_book_outlined,
      isPro: false,
      shortDescription: 'Formal, conservative layout for corporate roles.',
      exampleTone: 'Professional',
    ),
    _TemplateInfo(
      name: 'Modern',
      icon: Icons.style_outlined,
      isPro: true,
      shortDescription: 'Clean layout with subtle accents for modern roles.',
      exampleTone: 'Confident',
    ),
    _TemplateInfo(
      name: 'Creative',
      icon: Icons.auto_awesome,
      isPro: true,
      shortDescription: 'Bold, expressive layout for creative jobs.',
      exampleTone: 'Energetic',
    ),
  ];
}

class _TemplateInfo {
  final String name;
  final IconData icon;
  final bool isPro;
  final String shortDescription;
  final String exampleTone;

  const _TemplateInfo({
    required this.name,
    required this.icon,
    required this.isPro,
    required this.shortDescription,
    required this.exampleTone,
  });
}
