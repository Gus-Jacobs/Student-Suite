import 'package:flutter/material.dart';

/// A [TextEditingController] that highlights text matching a regex.
class PlaceholderHighlightingController extends TextEditingController {
  final RegExp placeholderRegex;
  final TextStyle placeholderStyle;
  final TextStyle? defaultStyle;

  PlaceholderHighlightingController({
    super.text,
    required this.placeholderRegex,
    required this.placeholderStyle,
    this.defaultStyle,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final effectiveStyle = style ?? defaultStyle ?? const TextStyle();

    text.splitMapJoin(
      placeholderRegex,
      onMatch: (Match match) {
        children.add(TextSpan(text: match.group(0), style: placeholderStyle));
        return '';
      },
      onNonMatch: (String nonMatch) {
        children.add(TextSpan(text: nonMatch, style: effectiveStyle));
        return '';
      },
    );

    return TextSpan(style: effectiveStyle, children: children);
  }
}
