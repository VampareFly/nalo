import 'package:flutter/material.dart';

class MedicalDisclaimerFooter extends StatelessWidget {
  const MedicalDisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'For wellness and informational purposes only. Not a medical '
        'device. Results are not intended to diagnose, treat, cure, or '
        'prevent any condition. Consult a healthcare provider for medical '
        'advice.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF777A86), fontSize: 10, height: 1.55),
      ),
    );
  }
}
