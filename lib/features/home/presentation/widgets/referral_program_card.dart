import 'package:flutter/material.dart';

class ReferralProgramCard extends StatelessWidget {
  const ReferralProgramCard({
    super.key,
    required this.referralCode,
    required this.onDismissed,
    required this.onCopyPressed,
    required this.onShareLinkPressed,
    required this.onMessagePressed,
  });

  final String referralCode;
  final VoidCallback onDismissed;
  final VoidCallback onCopyPressed;
  final VoidCallback onShareLinkPressed;
  final VoidCallback onMessagePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REFERRAL',
                      style: TextStyle(color: Color(0xFFA9B5F4), fontSize: 10, height: 1, fontWeight: FontWeight.w500, letterSpacing: 1.4),
                    ),
                    SizedBox(height: 11),
                    Text(
                      'Give 15%, get 15%',
                      style: TextStyle(
                        color: Color(0xFF202023),
                        fontFamily: 'Times New Roman',
                        fontSize: 21,
                        height: 1,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismissed,
                tooltip: 'Dismiss referral offer',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 30, height: 30),
                icon: Icon(Icons.close, color: Color(0xFF77777A), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Share your code and you both save 15% on the next order.',
            style: TextStyle(color: Color(0xFF77777A), fontSize: 13, height: 1.35),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF202023), fontSize: 13, height: 1, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                        ),
                      ),
                      const Icon(Icons.copy_outlined, color: Color(0xFFA9B5F4), size: 16),
                      const SizedBox(width: 5),
                      const Text(
                        'Copy',
                        style: TextStyle(color: Color(0xFFA9B5F4), fontSize: 12, height: 1, fontWeight: FontWeight.w500),
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
              Expanded(child: _ReferralActionButton(label: 'Share link', onPressed: onShareLinkPressed)),
              const SizedBox(width: 10),
              Expanded(child: _ReferralActionButton(label: 'Message', onPressed: onMessagePressed)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralActionButton extends StatelessWidget {
  const _ReferralActionButton({required this.label, required this.onPressed});

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
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: Text(label),
    );
  }
}
