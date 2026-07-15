import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:tester_kit/features/profile/presentation/widgets/profile_subpage_widgets.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  static const path = '/profile/help';

  @override
  Widget build(BuildContext context) {
    return ProfileSubpageScaffold(
      title: 'Help & FAQ',
      children: [
        const Text(
          'Quick answers about your Nola kit, testing routine, and results.',
          style: TextStyle(color: Color(0xFF717277), fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        const ProfileSectionCard(
          title: 'COMMON QUESTIONS',
          children: [
            _FaqTile(question: 'When should I take my test?', answer: 'Follow the timing shown with your active test kit. Consistent timing helps make trends easier to compare.'),
            _FaqTile(question: 'How do I record a result?', answer: 'Use the Create action on the home screen and follow the guided capture steps.'),
            _FaqTile(question: 'What if a test does not scan?', answer: 'Use bright, even lighting, keep the strip flat, and make sure the full test area is visible.'),
            _FaqTile(question: 'Are results a medical diagnosis?', answer: 'No. Nola results are for wellness and informational purposes and are not a medical diagnosis.'),
          ],
        ),
        const SizedBox(height: 18),
        ProfileSectionCard(
          children: [
            ProfileSettingRow(
              title: 'Contact support',
              subtitle: 'Get help from the Nola team',
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF68686B)),
              onPressed: () {
                // TODO: <pf> Open the support channel after contact details are confirmed.
                BotToast.showText(text: 'Support contact is coming soon', align: Alignment.center);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 42, 18),
      title: Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      children: [Text(answer, style: const TextStyle(color: Color(0xFF717277), fontSize: 13, height: 1.45))],
    ),
  );
}
