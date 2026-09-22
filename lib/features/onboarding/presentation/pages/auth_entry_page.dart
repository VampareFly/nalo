// 登录注册入口页，展示 Shopify快捷登录与仅限 iOS的 Apple入口。
// 各入口达到可见阈值时去重上报曝光，点击时携带当前页面组合状态。

import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/app/navigation/initial_page_ready_provider.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/auth/last_shopify_account_storage.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/presentation/widgets/nalo_brand.dart';
import 'package:nalo/features/onboarding/repositories/auth_entry_config_repository.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';
import 'package:nalo/features/onboarding/view_models/auth_entry_view_model.dart';
import 'package:nalo/features/shop/presentation/pages/guest_kit_shop_page.dart';
import 'package:nalo/features/shop/providers/pending_kit_purchase_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Figma 登录注册流程的统一入口页面。
class AuthEntryPage extends ConsumerStatefulWidget {
  const AuthEntryPage({super.key});

  static const path = '/auth';

  @override
  ConsumerState<AuthEntryPage> createState() => _AuthEntryPageState();
}

/// 准备 ATT 用户属性，并展示缓存与服务端决定的登录入口。
class _AuthEntryPageState extends ConsumerState<AuthEntryPage> {
  final Set<AnalyticsLoginClickMethod> _viewedLoginMethods = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(initialPageReadyProvider.notifier).markReady();
      unawaited(ref.prepareAnalyticsTrackingAuthorization());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authEntryViewModelProvider);
    final isAnyAuthenticationBusy = state.isLoading;
    final initialShowAppleLogin = ref.watch(initialShowAppleLoginProvider);
    final lastShopifyAccountState = ref.watch(lastShopifyAccountProvider);
    final lastShopifyAccount = lastShopifyAccountState.value;
    final isLastShopifyAccountLoading =
        lastShopifyAccountState.isLoading && !lastShopifyAccountState.hasValue;
    final showAppleLogin = Platform.isIOS
        ? (ref.watch(showAppleLoginProvider).value ?? initialShowAppleLogin)
        : false;
    final hasSavedShopifyAccount = lastShopifyAccount != null;
    final loginVisibilityContext =
        '${isLastShopifyAccountLoading ? 'loading' : hasSavedShopifyAccount ? 'saved' : 'new'}-'
        '${showAppleLogin ? 'apple' : 'no-apple'}';

    Map<AnalyticsEventProperty, Object> loginMethodProperties(
      AnalyticsLoginClickMethod method,
    ) => {
      AnalyticsEventProperty.pageName: AnalyticsPageName.loginSignIn.value,
      AnalyticsEventProperty.method: method.value,
      AnalyticsEventProperty.hasSavedShopifyAccount:
          hasSavedShopifyAccount ? 1 : 0,
      AnalyticsEventProperty.appleVisible: showAppleLogin ? 1 : 0,
    };

    void reportLoginMethodView(
      AnalyticsLoginClickMethod method,
      double visibleFraction,
    ) {
      if (isLastShopifyAccountLoading ||
          visibleFraction < 0.1 ||
          !_viewedLoginMethods.add(method)) {
        return;
      }
      unawaited(
        ref.report(
          AnalyticsEvent.loginMethodView,
          properties: loginMethodProperties(method),
        ),
      );
    }

    void reportLoginClick(AnalyticsLoginClickMethod method) {
      unawaited(
        ref.report(
          AnalyticsEvent.loginClick,
          properties: loginMethodProperties(method),
        ),
      );
    }

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
              result.loginProvider,
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

    Future<void> authorize(
      ShopifyAuthIntent intent, {
      bool forceLogin = true,
      bool useReturningAccount = false,
      AnalyticsLoginClickMethod clickMethod =
          AnalyticsLoginClickMethod.continueWithShopify,
    }) async {
      if (intent != ShopifyAuthIntent.kitPurchase) {
        ref.read(pendingKitPurchaseProvider.notifier).clear();
      }
      switch (intent) {
        case ShopifyAuthIntent.loginOrSignUp:
          reportLoginClick(clickMethod);
          break;
        case ShopifyAuthIntent.signIn:
          reportLoginClick(AnalyticsLoginClickMethod.signIn);
          break;
        case ShopifyAuthIntent.kitPurchase:
          unawaited(ref.report(AnalyticsEvent.iNeedKitClick));
          break;
      }
      EasyLoading.show();
      final viewModel = ref.read(authEntryViewModelProvider.notifier);
      final result = useReturningAccount
          ? await viewModel.authorizeReturningShopify(intent)
          : await viewModel.authorize(intent, forceLogin: forceLogin);
      EasyLoading.dismiss();
      handleAuthorizationResult(result);
    }

    Future<void> authorizeApple() async {
      ref.read(pendingKitPurchaseProvider.notifier).clear();
      reportLoginClick(AnalyticsLoginClickMethod.continueWithApple);
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
                        if (lastShopifyAccount == null)
                          _LoginMethodVisibility(
                            method:
                                AnalyticsLoginClickMethod.continueWithShopify,
                            trackingContext: loginVisibilityContext,
                            onVisibilityChanged: reportLoginMethodView,
                            child: _PillButton(
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
                                  : () => authorize(
                                      ShopifyAuthIntent.loginOrSignUp,
                                    ),
                            ),
                          )
                        else
                          _ReturningShopifyAccount(
                            maskedEmail: lastShopifyAccount.maskedEmail,
                            isEnabled: !isAnyAuthenticationBusy,
                            onContinue: () => authorize(
                              ShopifyAuthIntent.loginOrSignUp,
                              useReturningAccount: true,
                              clickMethod: AnalyticsLoginClickMethod
                                  .continueAsShopifyAccount,
                            ),
                            onUseAnotherAccount: () => authorize(
                              ShopifyAuthIntent.loginOrSignUp,
                              forceLogin: true,
                              clickMethod: AnalyticsLoginClickMethod
                                  .useAnotherShopifyAccount,
                            ),
                            onVisibilityChanged: reportLoginMethodView,
                            trackingContext: loginVisibilityContext,
                          ),
                        if (showAppleLogin) ...[
                          const SizedBox(height: 12),
                          _LoginMethodVisibility(
                            method:
                                AnalyticsLoginClickMethod.continueWithApple,
                            trackingContext: loginVisibilityContext,
                            onVisibilityChanged: reportLoginMethodView,
                            child: _AppleLoginButton(
                              onPressed: isAnyAuthenticationBusy
                                  ? null
                                  : authorizeApple,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: isAnyAuthenticationBusy
                        ? null
                        : () {
                            unawaited(
                              ref.report(AnalyticsEvent.iNeedKitClick),
                            );
                            context.push(GuestKitShopPage.path);
                          },
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
                  _LoginMethodVisibility(
                    method: AnalyticsLoginClickMethod.signIn,
                    trackingContext: loginVisibilityContext,
                    onVisibilityChanged: reportLoginMethodView,
                    child: TextButton(
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

/// 观察单个登录入口的实际可见比例，并将入口类型交给页面统一去重上报。
class _LoginMethodVisibility extends StatelessWidget {
  const _LoginMethodVisibility({
    required this.method,
    required this.trackingContext,
    required this.onVisibilityChanged,
    required this.child,
  });

  final AnalyticsLoginClickMethod method;
  final String trackingContext;
  final void Function(
    AnalyticsLoginClickMethod method,
    double visibleFraction,
  ) onVisibilityChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('login-method-${method.value}-$trackingContext'),
      onVisibilityChanged: (info) =>
          onVisibilityChanged(method, info.visibleFraction),
      child: child,
    );
  }
}

/// 展示最近 Shopify 账号，并提供复用 Session 或重新登录两个入口。
class _ReturningShopifyAccount extends StatelessWidget {
  const _ReturningShopifyAccount({
    required this.maskedEmail,
    required this.isEnabled,
    required this.onContinue,
    required this.onUseAnotherAccount,
    required this.onVisibilityChanged,
    required this.trackingContext,
  });

  final String maskedEmail;
  final bool isEnabled;
  final VoidCallback onContinue;
  final VoidCallback onUseAnotherAccount;
  final void Function(
    AnalyticsLoginClickMethod method,
    double visibleFraction,
  ) onVisibilityChanged;
  final String trackingContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last used Shopify account',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/icons/shopify_login.png',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 18, color: Color(0xFFB5BBC4)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  maskedEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Last used',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LoginMethodVisibility(
          method: AnalyticsLoginClickMethod.continueAsShopifyAccount,
          trackingContext: trackingContext,
          onVisibilityChanged: onVisibilityChanged,
          child: _PillButton(
            label: 'Continue as $maskedEmail',
            foregroundColor: const Color(0xFF008BC7),
            backgroundColor: Colors.white,
            onPressed: isEnabled ? onContinue : null,
          ),
        ),
        const SizedBox(height: 10),
        _LoginMethodVisibility(
          method: AnalyticsLoginClickMethod.useAnotherShopifyAccount,
          trackingContext: trackingContext,
          onVisibilityChanged: onVisibilityChanged,
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: isEnabled ? onUseAnotherAccount : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                shape: const StadiumBorder(),
                overlayColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Use another Shopify account'),
            ),
          ),
        ),
      ],
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
      child: FilledButton(
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
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
