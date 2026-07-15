import 'package:flutter/material.dart';
import 'package:tester_kit/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:tester_kit/features/profile/presentation/widgets/profile_subpage_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const path = '/profile/about';

  @override
  Widget build(BuildContext context) {
    return const ProfileSubpageScaffold(
      title: 'About Nola Test Kit',
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFF91A2E4),
                child: Text('N', style: TextStyle(color: Colors.white, fontFamily: 'Times New Roman', fontSize: 38, fontStyle: FontStyle.italic)),
              ),
              SizedBox(height: 16),
              Text('Nola Test Kit', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              SizedBox(height: 6),
              Text('Version 1.0.0', style: TextStyle(color: Color(0xFF77777A), fontSize: 13)),
            ],
          ),
        ),
        SizedBox(height: 28),
        ProfileSectionCard(
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nola helps you build a clearer picture of your wellness through at-home testing and easy-to-understand trends.',
                style: TextStyle(color: Color(0xFF55565A), fontSize: 14, height: 1.55),
              ),
            ),
          ],
        ),
        SizedBox(height: 38),
        MedicalDisclaimerFooter(),
      ],
    );
  }
}
