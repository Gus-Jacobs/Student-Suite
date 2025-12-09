import 'dart:typed_data';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:student_suite/models/saved_document.dart';
import 'package:student_suite/providers/auth_provider.dart';

class ResumeEditorScreen extends StatefulWidget {
  final Map<String, dynamic> initialContent;
  final Map<String, String> contactInfo;
  final String templateName;
  final String? documentId; // Add this

  const ResumeEditorScreen({
    super.key,
    required this.initialContent,
    required this.contactInfo,
    required this.templateName,
    this.documentId, // Add this
  });

  @override
  State<ResumeEditorScreen> createState() => _ResumeEditorScreenState();
}

class _ResumeEditorScreenState extends State<ResumeEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _data;

  // Customization State
  String _selectedFont = 'Roboto';
  PdfColor _selectedColor = PdfColors.blue800;
  double _fontSize = 11.0;
  double _lineSpacing = 1.5;
  pw.TextAlign _textAlignment = pw.TextAlign.left;

  // Section Order (Default)
  List<String> _sectionOrder = [
    'Summary',
    'Experience',
    'Education',
    'Skills',
    'Certificates'
  ];

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _data = Map.from(widget.initialContent);
    if (!_data.containsKey('contact')) {
      _data['contact'] = Map<String, String>.from(widget.contactInfo);
    }
    _nameController.text = _data['contact']['name'] ?? '';
    _summaryController.text = _data['professional_summary'] ?? '';
  }

  Future<void> _saveDocument() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final TextEditingController titleController = TextEditingController();

    // If we are updating an existing doc, pre-fill title could be tricky
    // unless we pass title in widget, but blank is fine for now.

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Resume"),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
              labelText: "Document Name (e.g. Google App)"),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(ctx);

                // Prepare Data
                final docId = widget.documentId ??
                    DateTime.now().millisecondsSinceEpoch.toString();
                final saveData = Map<String, dynamic>.from(_data);

                // Ensure contact info is synced into the map
                saveData['contact'] = {
                  'name': _nameController.text,
                  'email': _data['contact']['email'],
                  // ... other contact fields from your state
                };

                final doc = SavedDocument(
                  id: docId,
                  title: titleController.text,
                  type: 'resume',
                  lastModified: DateTime.now(),
                  content: saveData,
                );

                auth.savedDocumentsBox.put(docId, doc);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Resume saved successfully!")),
                );
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _summaryController.dispose();
    super.dispose();
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
          title: const Text('Resume Builder'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: "Save Project",
              onPressed: _saveDocument, // This calls your existing function
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: currentTheme.primaryAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.edit_note), text: "Edit & Design"),
              Tab(icon: Icon(Icons.picture_as_pdf), text: "Preview"),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEditTab(),
            _buildPreviewTab(),
          ],
        ),
      ),
    );
  }

  // --- GLASS CONTAINER HELPER ---
  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: child,
        ),
      ),
    );
  }

  // --- EDIT TAB ---
  Widget _buildEditTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- DESIGN SETTINGS ---
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DESIGN SETTINGS",
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 16),

              // Color Picker
              Row(
                children: [
                  const Text("Color:", style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 16),
                  _buildColorCircle(PdfColors.blue800),
                  _buildColorCircle(PdfColors.red800),
                  _buildColorCircle(PdfColors.green800),
                  _buildColorCircle(PdfColors.black),
                  _buildColorCircle(PdfColors.orange800),
                ],
              ),
              const SizedBox(height: 16),

              // Font Dropdown
              Row(
                children: [
                  const Text("Font:", style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedFont,
                    dropdownColor: Colors.grey[900],
                    style: const TextStyle(color: Colors.white),
                    items: [
                      'Roboto',
                      'Open Sans',
                      'Lato',
                      'Merriweather',
                      'Courier'
                    ]
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedFont = v!),
                  ),
                ],
              ),

              // Font Size Slider
              Row(
                children: [
                  const Text("Size:", style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 8,
                      max: 16,
                      divisions: 8,
                      label: _fontSize.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                ],
              ),

              // Line Spacing
              Row(
                children: [
                  const Text("Spacing:", style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _lineSpacing,
                      min: 1.0,
                      max: 2.0,
                      divisions: 10,
                      label: _lineSpacing.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _lineSpacing = v),
                    ),
                  ),
                ],
              ),

              // Alignment
              Row(
                children: [
                  const Text("Align:", style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 16),
                  ToggleButtons(
                    isSelected: [
                      _textAlignment == pw.TextAlign.left,
                      _textAlignment == pw.TextAlign.center,
                      _textAlignment == pw.TextAlign.right
                    ],
                    onPressed: (idx) {
                      setState(() {
                        if (idx == 0) _textAlignment = pw.TextAlign.left;
                        if (idx == 1) _textAlignment = pw.TextAlign.center;
                        if (idx == 2) _textAlignment = pw.TextAlign.right;
                      });
                    },
                    color: Colors.white54,
                    selectedColor: Colors.white,
                    fillColor: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Icon(Icons.format_align_left),
                      Icon(Icons.format_align_center),
                      Icon(Icons.format_align_right)
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- SECTION REORDERING ---
        _buildGlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("REORDER SECTIONS",
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ReorderableListView(
                  proxyDecorator: (child, index, animation) =>
                      Material(color: Colors.transparent, child: child),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final item = _sectionOrder.removeAt(oldIndex);
                      _sectionOrder.insert(newIndex, item);
                    });
                  },
                  children: _sectionOrder.map((section) {
                    return ListTile(
                      key: ValueKey(section),
                      title: Text(section,
                          style: const TextStyle(color: Colors.white)),
                      leading:
                          const Icon(Icons.drag_handle, color: Colors.white54),
                      tileColor: Colors.white.withAlpha(10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- BASIC INFO ---
        _buildSectionTitle("Basic Info"),
        _buildGlassContainer(
          child: Column(
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                onChanged: (val) => _data['contact']['name'] = val,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _summaryController,
                label: 'Professional Summary',
                maxLines: 4,
                onChanged: (val) => _data['professional_summary'] = val,
              ),
            ],
          ),
        ),

        _buildSectionTitle("Experience"),
        ..._buildDynamicList(
          _data['formatted_experience'] as List,
          (item, index) => _buildExperienceCard(item, index),
          () => {
            'company': '',
            'title': '',
            'dates': '',
            'bullet_points': ['Achievement']
          },
        ),

        _buildSectionTitle("Education"),
        ..._buildDynamicList(
          _data['formatted_education'] as List,
          (item, index) => _buildEducationCard(item, index),
          () => {'school': '', 'degree': '', 'grad_date': ''},
        ),

        _buildSectionTitle("Skills"),
        _buildGlassContainer(
          child: Column(
            children: [
              _buildSkillsField(
                  "Hard Skills", _data['skills_section']['hard_skills']),
              const SizedBox(height: 16),
              _buildSkillsField(
                  "Soft Skills", _data['skills_section']['soft_skills']),
            ],
          ),
        ),
        const SizedBox(height: 80), // Bottom spacer
      ],
    );
  }

  Widget _buildColorCircle(PdfColor color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color(color.toInt()),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: [
            if (isSelected)
              const BoxShadow(color: Colors.black45, blurRadius: 4)
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withAlpha(50))),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white)),
        filled: true,
        fillColor: Colors.black.withAlpha(30),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildPreviewTab() {
    return PdfPreview(
      build: (format) => _generatePdf(format),
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: true, // Enables the margin/layout view button you liked
      pdfPreviewPageDecoration: const BoxDecoration(
        color: Colors.transparent, // Makes the background transparent
      ),
      loadingWidget: const Center(child: CircularProgressIndicator()),
      actions: [
        PdfPreviewAction(
          icon: const Icon(Icons.download_rounded),
          onPressed: (context, build, pageFormat) async {
            // Native download/share
            await Printing.sharePdf(
                bytes: await build(pageFormat), filename: 'my_resume.pdf');
          },
        ),
      ],
    );
  }

  // --- EDITING HELPERS ---
  List<Widget> _buildDynamicList(
      List list, Widget Function(Map, int) builder, Map Function() createNew) {
    List<Widget> widgets = [];
    for (int i = 0; i < list.length; i++) {
      widgets.add(builder(list[i], i));
    }
    widgets.add(Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ElevatedButton.icon(
        onPressed: () => setState(() => list.add(createNew())),
        icon: const Icon(Icons.add),
        label: const Text("Add Item"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withAlpha(30),
          foregroundColor: Colors.white,
        ),
      ),
    ));
    return widgets;
  }

  Widget _buildExperienceCard(Map item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildGlassContainer(
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    setState(() => (_data['formatted_experience'] as List)
                        .removeAt(index));
                  })
            ]),
            _buildMapTextField(item, 'company', 'Company'),
            const SizedBox(height: 8),
            _buildMapTextField(item, 'title', 'Job Title'),
            const SizedBox(height: 8),
            _buildMapTextField(item, 'dates', 'Dates'),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationCard(Map item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildGlassContainer(
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    setState(() =>
                        (_data['formatted_education'] as List).removeAt(index));
                  })
            ]),
            _buildMapTextField(item, 'school', 'School / University'),
            const SizedBox(height: 8),
            _buildMapTextField(item, 'degree', 'Degree'),
            const SizedBox(height: 8),
            _buildMapTextField(item, 'grad_date', 'Graduation Year'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTextField(Map item, String key, String label) {
    return TextFormField(
      initialValue: item[key],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withAlpha(50))),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white)),
        filled: true,
        fillColor: Colors.black.withAlpha(30),
      ),
      onChanged: (val) => item[key] = val,
    );
  }

  Widget _buildSkillsField(String label, List skillsList) {
    final controller = TextEditingController(text: skillsList.join(', '));
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: "Java, Python, C++",
        hintStyle: const TextStyle(color: Colors.white30),
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withAlpha(50))),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white)),
        filled: true,
        fillColor: Colors.black.withAlpha(30),
      ),
      onChanged: (val) {
        final newSkills = val
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (label == "Hard Skills") {
          _data['skills_section']['hard_skills'] = newSkills;
        } else {
          _data['skills_section']['soft_skills'] = newSkills;
        }
      },
    );
  }

  // --- PDF GENERATION ---
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();

    // Dynamic Font Loading
    pw.Font fontRegular;
    pw.Font fontBold;

    switch (_selectedFont) {
      case 'Open Sans':
        fontRegular = await PdfGoogleFonts.openSansRegular();
        fontBold = await PdfGoogleFonts.openSansBold();
        break;
      case 'Lato':
        fontRegular = await PdfGoogleFonts.latoRegular();
        fontBold = await PdfGoogleFonts.latoBold();
        break;
      case 'Merriweather':
        fontRegular = await PdfGoogleFonts.merriweatherRegular();
        fontBold = await PdfGoogleFonts.merriweatherBold();
        break;
      case 'Courier':
        fontRegular = await PdfGoogleFonts.courierPrimeRegular();
        fontBold = await PdfGoogleFonts.courierPrimeBold();
        break;
      case 'Roboto':
      default:
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
    }

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          // Helper to get a section widget by name
          pw.Widget getSection(String name) {
            switch (name) {
              case 'Summary':
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfSectionHeader("Professional Summary", fontBold),
                      pw.Text(_data['professional_summary'] ?? '',
                          style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: _fontSize,
                              lineSpacing: _lineSpacing),
                          textAlign: _textAlignment),
                      pw.SizedBox(height: 16),
                    ]);
              case 'Experience':
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfSectionHeader("Experience", fontBold),
                      ...(_data['formatted_experience'] as List).map((exp) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 12),
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(
                                    mainAxisAlignment:
                                        pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text(exp['company'] ?? '',
                                          style: pw.TextStyle(
                                              font: fontBold,
                                              fontSize: _fontSize + 1)),
                                      pw.Text(exp['dates'] ?? '',
                                          style: pw.TextStyle(
                                              font: fontRegular,
                                              fontSize: _fontSize - 1,
                                              fontStyle: pw.FontStyle.italic)),
                                    ]),
                                pw.Text(exp['title'] ?? '',
                                    style: pw.TextStyle(
                                        font: fontRegular,
                                        fontSize: _fontSize,
                                        fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 4),
                                ...(exp['bullet_points'] as List).map((bp) =>
                                    pw.Row(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text("• ",
                                              style: pw.TextStyle(
                                                  font: fontRegular,
                                                  fontSize: _fontSize)),
                                          pw.Expanded(
                                              child: pw.Text(bp.toString(),
                                                  style: pw.TextStyle(
                                                      font: fontRegular,
                                                      fontSize: _fontSize,
                                                      lineSpacing:
                                                          _lineSpacing),
                                                  textAlign: _textAlignment)),
                                        ])),
                              ]),
                        );
                      }),
                      pw.SizedBox(height: 8),
                    ]);
              case 'Education':
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfSectionHeader("Education", fontBold),
                      ...(_data['formatted_education'] as List).map((edu) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(edu['school'] ?? '',
                                    style: pw.TextStyle(
                                        font: fontBold,
                                        fontSize: _fontSize + 1)),
                                pw.Text(
                                    "${edu['degree'] ?? ''} • ${edu['grad_date'] ?? ''}",
                                    style: pw.TextStyle(
                                        font: fontRegular,
                                        fontSize: _fontSize,
                                        lineSpacing: _lineSpacing)),
                              ]),
                        );
                      }),
                      pw.SizedBox(height: 16),
                    ]);
              case 'Skills':
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfSectionHeader("Skills", fontBold),
                      pw.Wrap(spacing: 8, runSpacing: 4, children: [
                        ...(_data['skills_section']['hard_skills'] as List)
                            .map((s) => pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                      borderRadius: const pw.BorderRadius.all(
                                          pw.Radius.circular(4)),
                                      color: PdfColors.grey200),
                                  child: pw.Text(s.toString(),
                                      style: pw.TextStyle(
                                          font: fontRegular,
                                          fontSize: _fontSize - 2)),
                                )),
                      ]),
                      pw.SizedBox(height: 16),
                    ]);
              default:
                return pw.SizedBox();
            }
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header (Fixed)
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_data['contact']['name'] ?? 'Your Name',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 24,
                            color: _selectedColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        "${_data['contact']['email'] ?? ''} | ${_data['contact']['phone'] ?? ''}",
                        style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 10,
                            color: PdfColors.grey700)),
                    if (_data['contact']['linkedin'] != null)
                      pw.Text(_data['contact']['linkedin']!,
                          style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                              color: _selectedColor)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Dynamic Sections based on Order
              ..._sectionOrder.map((sectionName) => getSection(sectionName)),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _buildPdfSectionHeader(String title, pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
              font: font,
              fontSize: _fontSize + 1,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
              color: _selectedColor),
        ),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 6),
      ],
    );
  }
}
