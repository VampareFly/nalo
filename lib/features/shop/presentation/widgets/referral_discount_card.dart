import 'package:flutter/material.dart';

class ReferralDiscountCard extends StatelessWidget {
  const ReferralDiscountCard({
    super.key,
    required this.referralCode,
    required this.onCopyPressed,
    required this.onShareLinkPressed,
    required this.onMessagePressed,
  });

  final String referralCode;
  final VoidCallback onCopyPressed;
  final VoidCallback onShareLinkPressed;
  final VoidCallback onMessagePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BEFORE YOU ORDER',
            style: TextStyle(color: Color(0xFFA9B5F4), fontSize: 10, height: 1, fontWeight: FontWeight.w500, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share your code first',
            style: TextStyle(
              color: Color(0xFF111113),
              fontFamily: 'Times New Roman',
              fontSize: 22,
              height: 1,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 17),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: Color(0xFF77777A), fontSize: 14, height: 1.45),
              children: [
                const TextSpan(text: 'Share '),
                TextSpan(text: referralCode, style: const TextStyle(color: Color(0xFF202023), fontWeight: FontWeight.w700)),
                const TextSpan(text: ' with a friend before they order — you both get 15% off.'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: const Color(0xFFF3F2F1),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onCopyPressed,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          referralCode,
                          style: const TextStyle(color: Color(0xFF202023), fontSize: 13, height: 1, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text(
                        'Copy code',
                        style: TextStyle(color: Color(0xFFA9B5F4), fontSize: 12, height: 1, fontWeight: FontWeight.w500, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _ReferralButton(label: 'Share link', onPressed: onShareLinkPressed)),
              const SizedBox(width: 10),
              Expanded(child: _ReferralButton(label: 'Message a friend', onPressed: onMessagePressed)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralButton extends StatelessWidget {
  const _ReferralButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF202023),
        side: const BorderSide(color: Color(0xFFE2E2E2)),
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
