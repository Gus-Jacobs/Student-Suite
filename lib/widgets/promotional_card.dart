import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_suite/providers/auth_provider.dart';

class PromotionsCard extends StatelessWidget {
  final void Function(String promoType)? onRedeem;

  const PromotionsCard({super.key, this.onRedeem});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final promotions = auth.activePromotions;

    if (promotions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: promotions.map((promo) {
        final type = promo['type'] ?? '';
        final desc = promo['description'] ?? '';
        final redeemable = promo['redeemable'] ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.amber.shade100,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.local_offer, color: Colors.deepOrange),
            title: Text(
              desc,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: redeemable
                ? ElevatedButton(
                    onPressed: () => onRedeem?.call(type),
                    child: const Text("Redeem"),
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      }).toList(),
    );
  }
}
