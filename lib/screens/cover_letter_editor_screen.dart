import 'dart:typed_data';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/theme_provider.dart';
import 'package:student_suite/widgets/placeholder_highlighting_controller.dart';
import 'package:student_suite/widgets/editor_field.dart'; // Ensure this widget exists or replace with standard TextField
import 'package:student_suite/models/saved_document.dart';
import 'package:student_suite/providers/auth_provider.dart';

class CoverLetterEditorScreen extends StatefulWidget {
  final Map<String, dynamic> initialContent;
  final String userName;
  final String templateName;
  final String? documentId; // <--- ADD THIS

  const CoverLetterEditorScreen({
    super.key,
    required this.initialContent,
    required this.userName,
    required this.templateName,
    this.documentId,
  });

  @override
  State<CoverLetterEditorScreen> createState() =>
      _CoverLetterEditorScreenState();
}

class _CoverLetterEditorScreenState extends State<CoverLetterEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  late PlaceholderHighlightingController _userNameController;
  late PlaceholderHighlightingController _salutationController;
  late PlaceholderHighlightingController _openingController;
  late List<PlaceholderHighlightingController> _bodyControllers;
  late PlaceholderHighlightingController _closingParagraphController;
  late PlaceholderHighlightingController _closingController;

  // Design State
  String _selectedFont = 'Roboto';
  PdfColor _selectedColor = PdfColors.black;
  double _fontSize = 12.0;
  double _lineSpacing = 1.5;
  pw.TextAlign _textAlignment = pw.TextAlign.left;

  final RegExp _placeholderRegex = RegExp(r'\[.*?\]');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final placeholderStyle = TextStyle(
      backgroundColor: Colors.amber.withAlpha((0.3 * 255).round()),
      color: Colors.amber.shade900,
      fontWeight: FontWeight.bold,
    );

    _userNameController = PlaceholderHighlightingController(
      text: widget.userName,
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );
    _salutationController = PlaceholderHighlightingController(
      text: widget.initialContent['salutation'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );
    _openingController = PlaceholderHighlightingController(
      text: widget.initialContent['opening_paragraph'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );

    final bodyParagraphs =
        (widget.initialContent['body_paragraphs'] as List<dynamic>? ?? [])
            .map((p) => p.toString())
            .toList();

    _bodyControllers = bodyParagraphs
        .map((p) => PlaceholderHighlightingController(
              text: p,
              placeholderRegex: _placeholderRegex,
              placeholderStyle: placeholderStyle,
            ))
        .toList();

    _closingParagraphController = PlaceholderHighlightingController(
      text: widget.initialContent['closing_paragraph'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );
    _closingController = PlaceholderHighlightingController(
      text: widget.initialContent['closing'] ?? '',
      placeholderRegex: _placeholderRegex,
      placeholderStyle: placeholderStyle,
    );
  }

  // 1. Helper to gather all text from controllers into a Map
  Map<String, dynamic> _snapshotContent() {
    return {
      'user_name': _userNameController.text,
      'salutation': _salutationController.text,
      'opening_paragraph': _openingController.text,
      'body_paragraphs': _bodyControllers.map((c) => c.text).toList(),
      'closing_paragraph': _closingParagraphController.text,
      'closing': _closingController.text,
      // You can also save design choices if you want:
      'font': _selectedFont,
      'color': _selectedColor.toInt(),
    };
  }

  // 2. The Save Function
  Future<void> _saveDocument() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final TextEditingController titleController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Cover Letter"),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
              labelText: "Document Name (e.g. Apple Cover Letter)"),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(ctx);

                // Use existing ID if updating, or generate new one
                final docId = widget.documentId ??
                    DateTime.now().millisecondsSinceEpoch.toString();

                final doc = SavedDocument(
                  id: docId,
                  title: titleController.text,
                  type: 'cover_letter', // Important tag
                  lastModified: DateTime.now(),
                  content: _snapshotContent(),
                );

                auth.savedDocumentsBox.put(docId, doc);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Cover Letter saved successfully!")),
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
    _userNameController.dispose();
    _salutationController.dispose();
    _openingController.dispose();
    for (var c in _bodyControllers) {
      c.dispose();
    }
    _closingParagraphController.dispose();
    _closingController.dispose();
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
          title: const Text('Cover Letter Builder'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: "Save Project",
              onPressed: _saveDocument,
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

  // --- UI HELPERS ---
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
              // Color
              Row(
                children: [
                  const Text("Color:", style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 16),
                  _buildColorCircle(PdfColors.black),
                  _buildColorCircle(PdfColors.blue800),
                  _buildColorCircle(PdfColors.red800),
                  _buildColorCircle(PdfColors.green800),
                ],
              ),
              const SizedBox(height: 16),
              // Font
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
              // Size
              Row(
                children: [
                  const Text("Size:", style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 10,
                      max: 18,
                      divisions: 8,
                      label: _fontSize.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- CONTENT EDITING ---
        _buildSectionTitle("Recipient & Greeting"),
        _buildGlassContainer(
          child: Column(
            children: [
              _buildEditorField(_userNameController, "Your Name"),
              const SizedBox(height: 12),
              _buildEditorField(_salutationController, "Salutation"),
            ],
          ),
        ),

        _buildSectionTitle("Letter Body"),
        _buildGlassContainer(
          child: Column(
            children: [
              _buildEditorField(_openingController, "Opening Paragraph",
                  maxLines: 5),
              const SizedBox(height: 12),
              ..._bodyControllers.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildEditorField(c, "Body Paragraph", maxLines: 6),
                  )),
              // Add Paragraph Button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _bodyControllers.add(PlaceholderHighlightingController(
                      text: "",
                      placeholderRegex: _placeholderRegex,
                      placeholderStyle: const TextStyle(
                          backgroundColor: Colors.amber,
                          color: Colors.black,
                          fontWeight: FontWeight.bold),
                    ));
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white70),
                label: const Text("Add Paragraph",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),

        _buildSectionTitle("Sign Off"),
        _buildGlassContainer(
          child: Column(
            children: [
              _buildEditorField(
                  _closingParagraphController, "Closing Statement",
                  maxLines: 3),
              const SizedBox(height: 12),
              _buildEditorField(
                  _closingController, "Sign Off (Sincerely, etc)"),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEditorField(TextEditingController controller, String label,
      {int maxLines = 1}) {
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

  // --- PREVIEW TAB ---
  Widget _buildPreviewTab() {
    return PdfPreview(
      build: (format) => _generatePdf(format),
      canChangeOrientation: false,
      canChangePageFormat: false,
      pdfPreviewPageDecoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      loadingWidget: const Center(child: CircularProgressIndicator()),
      actions: [
        PdfPreviewAction(
          icon: const Icon(Icons.download_rounded),
          onPressed: (context, build, pageFormat) async {
            await Printing.sharePdf(
                bytes: await build(pageFormat), filename: 'cover_letter.pdf');
          },
        ),
      ],
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final font = await _loadFont(_selectedFont);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Salutation
              pw.Text(_sanitize(_salutationController.text),
                  style: pw.TextStyle(font: font, fontSize: _fontSize)),
              pw.SizedBox(height: 15),

              // Opening
              pw.Text(_sanitize(_openingController.text),
                  style: pw.TextStyle(
                      font: font,
                      fontSize: _fontSize,
                      lineSpacing: _lineSpacing),
                  textAlign: _textAlignment),
              pw.SizedBox(height: 10),

              // Body Paragraphs
              ..._bodyControllers.map((c) {
                if (c.text.trim().isEmpty) return pw.SizedBox();
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 10),
                  child: pw.Text(_sanitize(c.text),
                      style: pw.TextStyle(
                          font: font,
                          fontSize: _fontSize,
                          lineSpacing: _lineSpacing),
                      textAlign: _textAlignment),
                );
              }),
              pw.SizedBox(height: 15),

              // Closing Paragraph
              pw.Text(_sanitize(_closingParagraphController.text),
                  style: pw.TextStyle(
                      font: font,
                      fontSize: _fontSize,
                      lineSpacing: _lineSpacing),
                  textAlign: _textAlignment),
              pw.SizedBox(height: 40),

              // Sign Off (Controlled entirely by the Editor Field now)
              pw.Text(_sanitize(_closingController.text),
                  style: pw.TextStyle(font: font, fontSize: _fontSize)),

              // REMOVED: The forced "Typed Name" variable is gone.
              // The user can now format the sign-off block manually in the UI.
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  Future<pw.Font> _loadFont(String fontName) async {
    switch (fontName) {
      case 'Open Sans':
        return PdfGoogleFonts.openSansRegular();
      case 'Lato':
        return PdfGoogleFonts.latoRegular();
      case 'Merriweather':
        return PdfGoogleFonts.merriweatherRegular();
      case 'Courier':
        return PdfGoogleFonts.courierPrimeRegular();
      case 'Roboto':
      default:
        return PdfGoogleFonts.robotoRegular();
    }
  }

  String _sanitize(String input) {
    return input
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('–', '-')
        .replaceAll('—', '--')
        .trim();
  }
}
