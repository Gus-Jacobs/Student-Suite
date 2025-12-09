import 'package:flutter/material.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final int maxLines;
  final bool isRequired;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction; // ✅ added

  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.maxLines = 1,
    this.isRequired = false,
    this.validator,
    this.textInputAction, // ✅ added
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: onSurfaceColor),
        maxLines: maxLines,
        textInputAction: textInputAction, // ✅ forward it to TextFormField
        decoration: InputDecoration(
          prefixIcon: icon != null
              ? Icon(icon, color: onSurfaceColor.withAlpha((0.7 * 255).round()))
              : null,
          labelText: label,
        ),
        validator: validator ??
            (value) => (isRequired && (value == null || value.trim().isEmpty))
                ? 'Please enter the $label.'
                : null,
      ),
    );
  }
}
