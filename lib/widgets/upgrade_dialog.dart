import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/auth_provider.dart';
import 'package:student_suite/providers/subscription_provider.dart';

void showUpgradeDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isFounder = auth.isFounder;
      final theme = Theme.of(context);

      return AlertDialog(
        title: const Text('Upgrade to Pro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Why pay for 3 different apps?'),
              const SizedBox(height: 12),

              // The Value Comparison "Invoice"
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _buildRow("Resume Builders", "~\$15/mo"),
                    _buildRow("AI Tutors", "~\$20/mo"),
                    _buildRow("Cover Letter AI", "~\$10/mo"),
                    const Divider(),
                    _buildRow(
                        "Student Suite", isFounder ? "\$5.99/mo" : "\$11.99/mo",
                        isTotal: true, context: context),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (isFounder)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Founder Status Detected: You get 50% OFF for life!",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              const Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Unlock AI Teacher & Interviewer')
              ]),
              const SizedBox(height: 8),
              const Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Unlimited Resume & Cover Letters')
              ]),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text(isFounder ? 'Claim Founder Offer' : 'Upgrade Now'),
            onPressed: () {
              Navigator.of(context).pop();
              final subscriptionProvider =
                  Provider.of<SubscriptionProvider>(context, listen: false);
              subscriptionProvider.buySubscription(isFounder);
            },
          ),
        ],
      );
    },
  );
}

Widget _buildRow(String label, String price,
    {bool isTotal = false, BuildContext? context}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            )),
        Text(price,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal
                  ? (context != null
                      ? Theme.of(context).colorScheme.primary
                      : Colors.green)
                  : null,
            )),
      ],
    ),
  );
}
