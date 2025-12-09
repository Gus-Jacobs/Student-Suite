import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';
// Import for kIsWeb

void showPostLoginUpgradeDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // User must interact with the dialog
    builder: (BuildContext context) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isFounder = auth.isFounder;

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch_outlined, color: Colors.amber),
            SizedBox(width: 10),
            Text('Go Pro!'),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              if (isFounder) ...[
                Text.rich(
                  TextSpan(
                    text: 'Get Pro for ',
                    children: <TextSpan>[
                      const TextSpan(
                        text: r'$12.99',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: r'$5.99 a month',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Limited time founders deal!'),
              ] else ...[
                const Text(
                  'Upgrade for just \$12.99 a month to use all our AI tools and ace your studies!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Maybe Later'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: const Text('Upgrade Now'),
            onPressed: () {
              final subscriptionProvider =
                  Provider.of<SubscriptionProvider>(context, listen: false);
              Navigator.of(context).pop();
              subscriptionProvider.buySubscription(isFounder);
            },
          ),
        ],
      );
    },
  );
}