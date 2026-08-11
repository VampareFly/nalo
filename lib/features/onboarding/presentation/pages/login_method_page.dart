import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/app/config/app_version_provider.dart';
import 'package:tester_kit/core/crash_reporting/crash_reporting_service.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/login_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/register_page.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_background.dart';
import 'package:tester_kit/features/onboarding/presentation/widgets/onboarding_button.dart';
import 'package:tester_kit/features/onboarding/view_models/shopify_auth_view_model.dart';

/// 登录选择页面
class LoginMethodPage extends ConsumerWidget {
  const LoginMethodPage({super.key});

  static const path = '/login-method';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopifyAuthState = ref.watch(shopifyAuthViewModelProvider);
    final isCrashlyticsTestVersion = ref.watch(
      appPackageInfoProvider.select(
        (packageInfo) => packageInfo.maybeWhen(
          data: (value) => value.version == crashlyticsTestVersion,
          orElse: () => false,
        ),
      ),
    );

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
                const SizedBox(height: 16),
                OnboardingButton(
                  label: shopifyAuthState.isLoading
                      ? 'Connecting to Shopify...'
                      : 'Login with Shopify',
                  isPrimary: false,
                  onPressed: () async {
                    if (shopifyAuthState.isBusy) return;
                    final message = await ref
                        .read(shopifyAuthViewModelProvider.notifier)
                        .login();
                    if (!context.mounted) return;
                    BotToast.showText(
                      text: message ?? 'Shopify login successful',
                      align: Alignment.center,
                    );
                  },
                ),
                const SizedBox(height: 16),
                OnboardingButton(
                  label: shopifyAuthState.isLoggingOut
                      ? 'Logging out from Shopify...'
                      : 'Logout from Shopify',
                  isPrimary: false,
                  onPressed: () async {
                    if (shopifyAuthState.isBusy) return;
                    final message = await ref
                        .read(shopifyAuthViewModelProvider.notifier)
                        .logout();
                    if (!context.mounted) return;
                    BotToast.showText(
                      text: message ?? 'Shopify logout successful',
                      align: Alignment.center,
                    );
                  },
                ),
                if (isCrashlyticsTestVersion) ...[
                  const SizedBox(height: 16),
                  OnboardingButton(
                    label: 'Trigger Test Crash',
                    isPrimary: false,
                    onPressed: CrashReportingService.triggerTestCrash,
                  ),
                ],
                const Spacer(flex: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
