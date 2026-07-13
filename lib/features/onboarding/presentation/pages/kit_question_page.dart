import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_background.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_button.dart';

class KitQuestionPage extends StatelessWidget {
  const KitQuestionPage({super.key});

  static const path = '/kit-question';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 4),
                Text(
                  'Do you have a Nola kit?',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 36,
                    fontStyle: FontStyle.italic,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Nola test strips ship to your door. Each pack has 3 '
                  'strips plus AI analysis of your results.',
                  style: const TextStyle(color: Color(0xFF717277), fontSize: 17, height: 1.45),
                ),
                const SizedBox(height: 30),
                OnboardingButton(
                  label: 'Yes, I have a kit',
                  onPressed: () {
                    // TODO: <pf> Replace the toast when kit activation is implemented.
                    BotToast.showText(text: 'Kit activation is coming soon');
                  },
                ),
                const SizedBox(height: 16),
                OnboardingButton(
                  label: 'Not yet — get one now!',
                  isPrimary: false,
                  onPressed: () {
                    // TODO: <pf> Replace the toast when kit purchasing is implemented.
                    BotToast.showText(text: 'Kit purchasing is coming soon');
                  },
                ),
                const Spacer(flex: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
