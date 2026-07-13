import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/login_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/register_page.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_background.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_button.dart';

/// 登录选择页面
class LoginMethodPage extends StatelessWidget {
  const LoginMethodPage({super.key});

  static const path = '/login-method';

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
                const Text(
                  // TODO: <pf> 文案需要确认
                  'Welcome to Nola.',
                  style: TextStyle(fontFamily: 'serif', fontSize: 40, fontStyle: FontStyle.italic, height: 1.1),
                ),
                const SizedBox(height: 18),
                const Text(
                  // TODO: <pf> 文案需要确认
                  'Your kit is the first step. Sign in to continue or create '
                  'an account to get started.',
                  style: TextStyle(color: Color(0xFF717277), fontSize: 17, height: 1.45),
                ),
                const SizedBox(height: 30),
                OnboardingButton(
                  label: 'Login',
                  onPressed: () => context.push(LoginPage.path),
                ),
                const SizedBox(height: 16),
                OnboardingButton(
                  label: 'Regist',
                  isPrimary: false,
                  onPressed: () => context.push(RegisterPage.path),
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
