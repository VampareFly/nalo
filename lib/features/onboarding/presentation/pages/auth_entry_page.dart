// 登录注册入口页，展示 Shopify 与仅限 iOS 的 Apple 认证入口。

import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/presentation/widgets/nalo_brand.dart';
import 'package:nalo/features/onboarding/repositories/auth_entry_config_repository.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';
import 'package:nalo/features/onboarding/view_models/auth_entry_view_model.dart';

/// Figma 登录注册流程的统一入口页面。
class AuthEntryPage extends ConsumerStatefulWidget {
  const AuthEntryPage({super.key});

  static const path = '/auth';

  @override
  ConsumerState<AuthEntryPage> createState() => _AuthEntryPageState();
}

/// 准备 ATT 用户属性，并展示缓存与服务端决定的登录入口。
class _AuthEntryPageState extends ConsumerState<AuthEntryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.prepareAnalyticsTrackingAuthorization());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authEntryViewModelProvider);
    final isAnyAuthenticationBusy = state.isLoading;
    final showAppleLogin = Platform.isIOS
        ? (ref.watch(showAppleLoginProvider).value ?? true)
        : false;

    void handleAuthorizationResult(OnboardingAuthResult? result) {
      if (!context.mounted) return;
      if (result == null) {
        final message = ref.read(authEntryViewModelProvider).errorMessage;
        if (message != null) {
          BotToast.showText(text: message, align: Alignment.center);
        }
        return;
      }
      switch (result.destination) {
        case OnboardingAuthDestination.accountProfile:
          context.go(
            AccountProfilePage.location(
              result.email ?? '',
              result.userId,
              result.completionDestination,
            ),
          );
          return;
        case OnboardingAuthDestination.welcome:
          context.go(
            OnboardingWelcomePage.location(
              result.fullName ?? '',
              result.userId,
              result.completionDestination,
            ),
          );
          return;
        case OnboardingAuthDestination.home:
          context.go(HomePage.path);
          return;
        case OnboardingAuthDestination.shop:
          context.go('${HomePage.path}?tab=shop');
          return;
      }
    }

    Future<void> authorize(ShopifyAuthIntent intent) async {
      switch (intent) {
        case ShopifyAuthIntent.loginOrSignUp:
          unawaited(
            ref.report(
              AnalyticsEvent.loginClick,
              properties: {
                AnalyticsEventProperty.method:
                    AnalyticsLoginClickMethod.continueWithShopify.value,
              },
            ),
          );
          break;
        case ShopifyAuthIntent.signIn:
          unawaited(
            ref.report(
              AnalyticsEvent.loginClick,
              properties: {
                AnalyticsEventProperty.method:
                    AnalyticsLoginClickMethod.signIn.value,
              },
            ),
          );
          break;
        case ShopifyAuthIntent.kitPurchase:
          unawaited(ref.report(AnalyticsEvent.iNeedKitClick));
          break;
      }
      EasyLoading.show();
      final result = await ref
          .read(authEntryViewModelProvider.notifier)
          .authorize(intent);
      EasyLoading.dismiss();
      handleAuthorizationResult(result);
    }

    Future<void> authorizeApple() async {
      unawaited(
        ref.report(
          AnalyticsEvent.loginClick,
          properties: {
            AnalyticsEventProperty.method:
                AnalyticsLoginClickMethod.continueWithApple.value,
          },
        ),
      );
      EasyLoading.show();
      final result = await ref
          .read(authEntryViewModelProvider.notifier)
          .authorizeApple();
      EasyLoading.dismiss();
      handleAuthorizationResult(result);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF008BC7),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  const NaloBrand(),
                  const SizedBox(height: 12),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Less guessing. '),
                        TextSpan(
                          text: 'More learning.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  _AuthCard(
                    title: 'Login or Sign up',
                    subtitle: 'Choose an account to continue.',
                    child: Column(
                      children: [
                        _PillButton(
                          label: 'Continue with Shopify',
                          foregroundColor: const Color(0xFF1A2433),
                          backgroundColor: Colors.white,
                          icon: Image.asset(
                            'assets/icons/shopify_login.png',
                            width: 24,
                            height: 24,
                          ),
                          onPressed: isAnyAuthenticationBusy
                              ? null
                              : () =>
                                    authorize(ShopifyAuthIntent.loginOrSignUp),
                        ),
                        if (showAppleLogin) ...[
                          const SizedBox(height: 12),
                          _AppleLoginButton(
                            onPressed: isAnyAuthenticationBusy
                                ? null
                                : authorizeApple,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: isAnyAuthenticationBusy
                        ? null
                        : () => authorize(ShopifyAuthIntent.kitPurchase),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'I need a kit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Browse our cortisol & testosterone test kits.',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CircleAvatar(
                            backgroundColor: Colors.white12,
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: isAnyAuthenticationBusy
                        ? null
                        : () => authorize(ShopifyAuthIntent.signIn),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      overlayColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                    ),
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon ?? const SizedBox.shrink(),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: foregroundColor,
          overlayColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          textStyle: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// 无按压变色效果的 Apple 登录按钮。
class _AppleLoginButton extends StatelessWidget {
  const _AppleLoginButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Continue with Apple',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apple, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Continue with Apple',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
