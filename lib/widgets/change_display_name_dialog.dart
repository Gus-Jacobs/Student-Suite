import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ChangeDisplayNameDialog extends StatefulWidget {
  const ChangeDisplayNameDialog({super.key});

  @override
  State<ChangeDisplayNameDialog> createState() =>
      _ChangeDisplayNameDialogState();
}

class _ChangeDisplayNameDialogState extends State<ChangeDisplayNameDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return AlertDialog(
      title: const Text('Change Display Name'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'New Display Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display Name is required.';
                }
                if (value.length < 3) {
                  return 'Display Name must be at least 3 characters.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Save'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final newDisplayName = _displayNameController.text.trim();

              try {
                await auth.updateDisplayName(newDisplayName);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Display Name updated!')),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update Display Name: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }
}
