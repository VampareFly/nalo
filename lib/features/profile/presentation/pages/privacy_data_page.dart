import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:tester_kit/features/profile/presentation/widgets/profile_subpage_widgets.dart';

class PrivacyDataPage extends StatelessWidget {
  const PrivacyDataPage({super.key});

  static const path = '/profile/privacy';

  @override
  Widget build(BuildContext context) {
    return ProfileSubpageScaffold(
      title: 'Privacy & data',
      children: [
        const Text(
          'Your profile and wellness information are used to personalize your experience and are not shared for advertising.',
          style: TextStyle(color: Color(0xFF717277), fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        ProfileSectionCard(
          title: 'LEGAL',
          children: [
            ProfileSettingRow(title: 'Privacy policy', trailing: const Icon(Icons.chevron_right, color: Color(0xFF68686B)), onPressed: () => _comingSoon('Privacy policy')),
            ProfileSettingRow(title: 'Terms of use', trailing: const Icon(Icons.chevron_right, color: Color(0xFF68686B)), onPressed: () => _comingSoon('Terms of use')),
          ],
        ),
        const SizedBox(height: 18),
        ProfileSectionCard(
          children: [
            ProfileSettingRow(
              title: 'Delete account',
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF68686B)),
              onPressed: () => _comingSoon('Account deletion'),
            ),
          ],
        ),
      ],
    );
  }

  void _comingSoon(String feature) {
    // TODO: <pf> Connect the privacy action after the legal and account endpoints are available.
    BotToast.showText(text: '$feature is coming soon', align: Alignment.center);
  }
}
