import 'dart:ui';
import 'package:flutter/material.dart';

class GlassEditorField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const GlassEditorField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  State<GlassEditorField> createState() => _GlassEditorFieldState();
}

class _GlassEditorFieldState extends State<GlassEditorField> {
  bool _containsPlaceholder = false;
  // This regex looks for text enclosed in square brackets, e.g., [Your Name]
  final RegExp _placeholderRegex = RegExp(r'\[.*?\]');

  @override
  void initState() {
    super.initState();
    _checkForPlaceholder();
    widget.controller.addListener(_checkForPlaceholder);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkForPlaceholder);
    super.dispose();
  }

  void _checkForPlaceholder() {
    if (mounted) {
      final newContainsPlaceholder =
          _placeholderRegex.hasMatch(widget.controller.text);
      if (newContainsPlaceholder != _containsPlaceholder) {
        setState(() {
          _containsPlaceholder = newContainsPlaceholder;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsAttentionColor = Colors.amber.shade400;
    final defaultBorderColor = Colors.white.withAlpha((0.2 * 255).round());

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha((0.3 * 255).round()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _containsPlaceholder
                    ? needsAttentionColor
                    : defaultBorderColor,
                width: _containsPlaceholder ? 1.5 : 1.0,
              ),
            ),
            child: TextFormField(
              controller: widget.controller,
              style: const TextStyle(color: Colors.white, height: 1.5),
              maxLines: widget.maxLines,
              decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: TextStyle(
                  color: _containsPlaceholder
                      ? needsAttentionColor
                      : Colors.white70,
                  fontWeight: _containsPlaceholder
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                border: InputBorder.none,
                suffixIcon: _containsPlaceholder
                    ? Tooltip(
                        message: 'Please replace the placeholder text.',
                        child:
                            Icon(Icons.edit_note, color: needsAttentionColor),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
