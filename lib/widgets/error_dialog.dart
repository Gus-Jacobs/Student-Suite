import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showErrorDialog(BuildContext context, String message, {String? details}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Error'),
      content: Text(message),
      actions: [
        if (details != null && details.isNotEmpty)
          TextButton(
            child: const Text('Copy Details'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: details));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error details copied")),
              );
            },
          ),
        TextButton(
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
