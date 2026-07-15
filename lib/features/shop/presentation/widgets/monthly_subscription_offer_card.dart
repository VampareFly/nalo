import 'package:flutter/material.dart';

class MonthlySubscriptionOfferCard extends StatelessWidget {
  const MonthlySubscriptionOfferCard({super.key, required this.onSubscribePressed});

  final VoidCallback onSubscribePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF8).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFCBD2F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 12, height: 1)),
              SizedBox(width: 8),
              Text(
                'BETTER VALUE',
                style: TextStyle(color: Color(0xFF91A5F1), fontSize: 10, height: 1, fontWeight: FontWeight.w500, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Save 10% every month',
            style: TextStyle(
              color: Color(0xFF111113),
              fontFamily: 'Times New Roman',
              fontSize: 23,
              height: 1,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'A subscription gets you 3 strips per month at 10% off — plus priority results, an AI coach, and a monthly PDF report. Cancel any time.',
            style: TextStyle(color: Color(0xFF77777A), fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 22),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(r'$13.50', style: TextStyle(color: Color(0xFF050505), fontSize: 27, height: 1, fontWeight: FontWeight.w700)),
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text('/mo', style: TextStyle(color: Color(0xFF77777A), fontSize: 14, height: 1)),
              ),
              Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(r'vs $15 one-off', style: TextStyle(color: Color(0xFF77777A), fontSize: 12, height: 1)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: onSubscribePressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF050505),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text('Subscribe & save  →'),
          ),
        ],
      ),
    );
  }
}
