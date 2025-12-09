import 'package:flutter/material.dart';
import 'package:student_suite/models/resume_data.dart';
import 'package:student_suite/models/contact_info_data.dart';
import 'package:student_suite/models/education_data.dart';
import 'package:student_suite/models/experience_data.dart';
import 'package:student_suite/models/certificate_data.dart';
import 'package:student_suite/mixins/tutorial_support_mixin.dart';
import 'package:student_suite/models/tutorial_step.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/screens/resume_editor_screen.dart';
import 'package:student_suite/services/ai_service.dart';
import 'package:student_suite/widgets/upgrade_dialog.dart';
import 'package:student_suite/widgets/error_dialog.dart';
import 'package:student_suite/widgets/glass_section.dart';
import 'package:student_suite/widgets/glass_text_field.dart';
import 'package:uuid/uuid.dart';
import '../providers/theme_provider.dart';
// For ImageFilter
import '../widgets/template_preview_card.dart';

/// --- Data entry helper classes --- ///
class _EducationEntry {
  final String id = const Uuid().v4();
  final schoolController = TextEditingController();
  final degreeController = TextEditingController();
  final gradDateController = TextEditingController();

  _EducationEntry();

  factory _EducationEntry.fromData(EducationData data) {
    final entry = _EducationEntry();
    entry.schoolController.text = data.school;
    entry.degreeController.text = data.degree;
    entry.gradDateController.text = data.gradDate;
    return entry;
  }

  void dispose() {
    schoolController.dispose();
    degreeController.dispose();
    gradDateController.dispose();
  }
}

class _ExperienceEntry {
  final String id = const Uuid().v4();
  final companyController = TextEditingController();
  final titleController = TextEditingController();
  final datesController = TextEditingController();
  final responsibilitiesController = TextEditingController();

  _ExperienceEntry();

  factory _ExperienceEntry.fromData(ExperienceData data) {
    final entry = _ExperienceEntry();
    entry.companyController.text = data.company;
    entry.titleController.text = data.title;
    entry.datesController.text = data.dates;
    entry.responsibilitiesController.text = data.responsibilities;
    return entry;
  }

  void dispose() {
    companyController.dispose();
    titleController.dispose();
    datesController.dispose();
    responsibilitiesController.dispose();
  }
}

class _CertificateEntry {
  final String id = const Uuid().v4();
  final nameController = TextEditingController();
  final orgController = TextEditingController();
  final dateController = TextEditingController();

  _CertificateEntry();

  factory _CertificateEntry.fromData(CertificateData data) {
    final entry = _CertificateEntry();
    entry.nameController.text = data.name;
    entry.orgController.text = data.organization;
    entry.dateController.text = data.date;
    return entry;
  }

  void dispose() {
    nameController.dispose();
    orgController.dispose();
    dateController.dispose();
  }
}

/// --- Main Resume Builder Screen --- ///
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});

  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen>
    with TutorialSupport<ResumeBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aiService = AiService();
  bool _isLoading = false;

  // Contact Info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();
  final _portfolioController = TextEditingController();

  // Skills
  final _skillController = TextEditingController();
  final List<String> _skills = [];

  // Dynamic Sections
  List<_EducationEntry> _educationEntries = [];
  List<_ExperienceEntry> _experienceEntries = [];
  List<_CertificateEntry> _certificateEntries = [];

  // Template
  String _selectedTemplate = 'Modern';

  @override
  String get tutorialKey => 'resume';

  @override
  List<TutorialStep> get tutorialSteps => const [
        TutorialStep(
          icon: Icons.input,
          title: 'Fill In Your Info',
          description:
              'Add your contact details, skills, work experience, and education. The more detail, the better!',
        ),
        TutorialStep(
          icon: Icons.auto_fix_high,
          title: 'Generate with AI',
          description:
              'Our AI will rewrite your experience into professional bullet points and generate a compelling summary.',
        ),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResumeData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _portfolioController.dispose();
    _skillController.dispose();
    for (var entry in _educationEntries) {
      entry.dispose();
    }
    for (var entry in _experienceEntries) {
      entry.dispose();
    }
    for (var entry in _certificateEntries) {
      entry.dispose();
    }
    if (mounted) {
      try {
        final auth = context.read<AuthProvider>();
        // If user is null, we are logging out. DO NOT SAVE.
        if (auth.user != null) {
          _saveResumeData();
        }
      } catch (e) {
        // Silently ignore save errors during dispose/logout
      }
    }
    super.dispose();
  }

  /// --- Entry Management --- ///
  void _addEducationEntry() =>
      setState(() => _educationEntries.add(_EducationEntry()));
  void _removeEducationEntry(String id) =>
      setState(() => _educationEntries.removeWhere((e) => e.id == id));

  void _addExperienceEntry() =>
      setState(() => _experienceEntries.add(_ExperienceEntry()));
  void _removeExperienceEntry(String id) =>
      setState(() => _experienceEntries.removeWhere((e) => e.id == id));

  void _addCertificateEntry() =>
      setState(() => _certificateEntries.add(_CertificateEntry()));
  void _removeCertificateEntry(String id) =>
      setState(() => _certificateEntries.removeWhere((c) => c.id == id));

  void _addSkill() {
    if (_skillController.text.trim().isNotEmpty) {
      setState(() {
        _skills.add(_skillController.text.trim());
        _skillController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() => _skills.remove(skill));
  }

  /// --- Data Persistence --- ///
  Future<void> _saveResumeData() async {
    final box = context.read<AuthProvider>().resumeDataBox;
    final resumeData = ResumeData(
      contactInfo: ContactInfoData(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        linkedin: _linkedinController.text,
        github: _githubController.text,
        portfolio: _portfolioController.text,
      ),
      skills: _skills,
      education: _educationEntries
          .map((e) => EducationData(
                school: e.schoolController.text,
                degree: e.degreeController.text,
                gradDate: e.gradDateController.text,
              ))
          .toList(),
      experience: _experienceEntries
          .map((e) => ExperienceData(
                company: e.companyController.text,
                title: e.titleController.text,
                dates: e.datesController.text,
                responsibilities: e.responsibilitiesController.text,
              ))
          .toList(),
      certificates: _certificateEntries
          .map((e) => CertificateData(
                name: e.nameController.text,
                organization: e.orgController.text,
                date: e.dateController.text,
              ))
          .toList(),
    );
    await box.put('current', resumeData);
  }

  Future<void> _loadResumeData() async {
    final box = context.read<AuthProvider>().resumeDataBox;
    final data = box.get('current');
    if (data != null) {
      _nameController.text = data.contactInfo.name;
      _emailController.text = data.contactInfo.email;
      _phoneController.text = data.contactInfo.phone;
      _linkedinController.text = data.contactInfo.linkedin;
      _githubController.text = data.contactInfo.github;
      _portfolioController.text = data.contactInfo.portfolio;

      setState(() {
        _skills.clear();
        _skills.addAll(data.skills);
        _educationEntries =
            data.education.map((e) => _EducationEntry.fromData(e)).toList();
        _experienceEntries =
            data.experience.map((e) => _ExperienceEntry.fromData(e)).toList();
        _certificateEntries = data.certificates
            .map((e) => _CertificateEntry.fromData(e))
            .toList();
      });
    } else {
      final auth = context.read<AuthProvider>();
      _nameController.text = auth.displayName;
      _emailController.text = auth.user?.email ?? '';
      setState(() {
        _addEducationEntry();
        _addExperienceEntry();
      });
    }
  }

  /// --- Build UI --- ///
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
          title: const Text('AI Resume Builder'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Open Saved Resumes',
              onPressed: () => Navigator.pushNamed(
                context,
                '/saved_documents',
                arguments: 0,
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
              GlassSection(
                title: 'Contact Information',
                icon: Icons.person_outline,
                initiallyExpanded: true,
                child: Column(
                  children: [
                    GlassTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        isRequired: true),
                    GlassTextField(
                        controller: _emailController,
                        label: 'Email',
                        isRequired: true),
                    GlassTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        isRequired: true),
                    GlassTextField(
                        controller: _linkedinController,
                        label: 'LinkedIn URL (Optional)'),
                    GlassTextField(
                        controller: _githubController,
                        label: 'GitHub URL (Optional)'),
                    GlassTextField(
                        controller: _portfolioController,
                        label: 'Portfolio/Website (Optional)'),
                  ],
                ),
              ),
              GlassSection(
                title: 'Skills',
                icon: Icons.lightbulb_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GlassTextField(
                              controller: _skillController,
                              label: 'Add a skill'),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle,
                              color: Theme.of(context).colorScheme.primary),
                          onPressed: _addSkill,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _skills
                          .map((skill) => Chip(
                                label: Text(skill),
                                onDeleted: () => _removeSkill(skill),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              ..._experienceEntries
                  .map((entry) => _buildExperienceEntry(entry)),
              _buildAddButton('Add Experience', _addExperienceEntry),
              ..._educationEntries.map((entry) => _buildEducationEntry(entry)),
              _buildAddButton('Add Education', _addEducationEntry),
              ..._certificateEntries
                  .map((entry) => _buildCertificateEntry(entry)),
              _buildAddButton('Add Certificate', _addCertificateEntry),
              const SizedBox(height: 16),
              Text('Select a Template',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildTemplateSelector(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isLoading ? 'Generating...' : 'Generate with AI'),
                onPressed: _isLoading ? null : _generateResume,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// --- Template Selection --- ///
  Widget _buildTemplateSelector() {
    const templates = ['Modern', 'Classic', 'Creative'];
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final templateName = templates[index];
          final isSelected = _selectedTemplate == templateName;
          return AnimatedScale(
            scale: isSelected ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: TemplatePreviewCard(
              templateName: templateName,
              icon: Icons.badge_outlined,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedTemplate = templateName),
            ),
          );
        },
      ),
    );
  }

  /// --- Resume Generation --- ///
  Future<void> _generateResume() async {
    final subscription =
        Provider.of<SubscriptionProvider>(context, listen: false);
    if (!subscription.isPro) {
      showUpgradeDialog(context);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      showErrorDialog(context,
          'Please fill out all required fields (Name, Email, Phone) before generating.');
      return;
    }

    await _saveResumeData();
    setState(() => _isLoading = true);

    try {
      final contactInfo = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'linkedin': _linkedinController.text.trim(),
        'github': _githubController.text.trim(),
        'portfolio': _portfolioController.text.trim(),
      };

      final experiences = _experienceEntries
          .map((e) => {
                'company': e.companyController.text.trim(),
                'title': e.titleController.text.trim(),
                'dates': e.datesController.text.trim(),
                'responsibilities': e.responsibilitiesController.text.trim(),
              })
          .toList();

      final education = _educationEntries
          .map((e) => {
                'school': e.schoolController.text.trim(),
                'degree': e.degreeController.text.trim(),
                'grad_date': e.gradDateController.text.trim(),
              })
          .toList();

      final certificates = _certificateEntries
          .map((e) => {
                'name': e.nameController.text.trim(),
                'organization': e.orgController.text.trim(),
                'date': e.dateController.text.trim(),
              })
          .toList();

      final generatedContent = await _aiService.generateResume(
        contactInfo: contactInfo,
        experiences: experiences,
        education: education,
        certificates: certificates,
        skills: _skills,
        templateStyle: _selectedTemplate,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ResumeEditorScreen(
            initialContent: generatedContent,
            contactInfo: contactInfo,
            templateName: _selectedTemplate,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorDialog(
            context, "Failed to generate resume. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// --- Entry Builders --- ///
  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context)
              .colorScheme
              .onSurface
              .withAlpha((0.9 * 255).round()),
          side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withAlpha((0.5 * 255).round())),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildExperienceEntry(_ExperienceEntry entry) {
    return GlassSection(
      title: 'Work Experience',
      icon: Icons.work_outline,
      onRemove: () => _removeExperienceEntry(entry.id),
      child: Column(
        children: [
          GlassTextField(
              controller: entry.companyController,
              label: 'Company',
              isRequired: true),
          GlassTextField(controller: entry.titleController, label: 'Job Title'),
          GlassTextField(
              controller: entry.datesController,
              label: 'Dates (e.g., Jan 2020 - Present)'),
          GlassTextField(
              controller: entry.responsibilitiesController,
              label: 'Responsibilities / Achievements',
              maxLines: 4),
        ],
      ),
    );
  }

  Widget _buildEducationEntry(_EducationEntry entry) {
    return GlassSection(
      title: 'Education',
      icon: Icons.school_outlined,
      onRemove: () => _removeEducationEntry(entry.id),
      child: Column(
        children: [
          GlassTextField(
            controller: entry.schoolController,
            label: 'School / University',
            isRequired: true,
          ),
          GlassTextField(
            controller: entry.degreeController,
            label: 'Degree / Field of Study',
          ),
          GlassTextField(
            controller: entry.gradDateController,
            label: 'Graduation Date',
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateEntry(_CertificateEntry entry) {
    return GlassSection(
      title: 'Certificate',
      icon: Icons.verified_outlined,
      onRemove: () => _removeCertificateEntry(entry.id),
      child: Column(
        children: [
          GlassTextField(
            controller: entry.nameController,
            label: 'Certificate Name',
          ),
          GlassTextField(
            controller: entry.orgController,
            label: 'Issuing Organization',
          ),
          GlassTextField(
            controller: entry.dateController,
            label: 'Date Issued',
          ),
        ],
      ),
    );
  }
}
