import 'package:amplitude_flutter/events/base_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/core/analytics/amplitude_provider.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/kit_question_page.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_background.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_button.dart';

class GetStartedPage extends ConsumerWidget {
  const GetStartedPage({super.key});

  static const path = '/get-started';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 7),
                Text(
                  'NOLA',
                  style: const TextStyle(color: Color(0xFF6F7075), fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 2),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Numbers\n',
                        style: const TextStyle(fontFamily: 'serif', fontSize: 48, fontStyle: FontStyle.italic, height: 0.95),
                      ),
                      TextSpan(
                        text: 'over vibes.',
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, height: 1.05),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Test your hormones at home with a saliva strip. '
                  'Get AI-powered insights. Act on facts instead of anxiety.',
                  style: const TextStyle(color: Color(0xFF717277), fontSize: 18, height: 1.55),
                ),
                const SizedBox(height: 34),
                OnboardingButton(
                  label: 'Get started',
                  onPressed: () {
                    DateTime now = DateTime.now();
                    ref.read(amplitudeProvider)?.track(BaseEvent('Get Started Clicked test$now))'));
                    context.push(KitQuestionPage.path);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
