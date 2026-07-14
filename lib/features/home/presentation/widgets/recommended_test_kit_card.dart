import 'package:flutter/material.dart';

class RecommendedTestKitCard extends StatelessWidget {
  const RecommendedTestKitCard({super.key, required this.onLearnMorePressed});

  final VoidCallback onLearnMorePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 124),
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALSO AVAILABLE',
                  style: TextStyle(color: Color(0xFFA9B5F4), fontSize: 10, height: 1, fontWeight: FontWeight.w500, letterSpacing: 1.6),
                ),
                SizedBox(height: 13),
                Text(
                  'Testosterone kit',
                  style: TextStyle(color: Color(0xFF202023), fontSize: 16, height: 1, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 7),
                Text(
                  'Track energy, drive, and muscle health ·\n\$18',
                  style: TextStyle(color: Color(0xFF77777A), fontSize: 12, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onLearnMorePressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF303035),
              side: const BorderSide(color: Color(0xFFE7E7E7)),
              fixedSize: const Size(92, 54),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 12, height: 1.25, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
            ),
            child: const Text('Learn\nmore', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
