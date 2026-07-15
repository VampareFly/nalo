import 'package:flutter/material.dart';
import 'package:tester_kit/features/shop/models/test_kit_product.dart';

class TestKitPurchaseCard extends StatelessWidget {
  const TestKitPurchaseCard({super.key, required this.product, required this.onOrderPressed});

  final TestKitProduct product;
  final VoidCallback onOrderPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 7))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 32, child: Text(product.icon, style: const TextStyle(fontSize: 25, height: 1))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(color: Color(0xFF111113), fontSize: 20, height: 1, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF77777A), fontSize: 13, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(product.price, style: const TextStyle(color: Color(0xFF050505), fontSize: 27, height: 1, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF4F5FC), borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    product.subscriptionPrice,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF91A5F1), fontSize: 12, height: 1, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onOrderPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF050505),
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 44),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: const Text('Order now'),
          ),
        ],
      ),
    );
  }
}
