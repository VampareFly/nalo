// 账号创建后的欢迎页，承接通知权限并按用户保存完成状态。
// 页面上报通知与开始点击；本地标记保存成功后才结束引导并进入首页。

import 'dart:async';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/repositories/welcome_completion_repository.dart';

/// 展示个性化欢迎信息并进入首页。
class OnboardingWelcomePage extends ConsumerStatefulWidget {
  const OnboardingWelcomePage({
    required this.fullName,
    required this.userId,
    this.completionDestination = OnboardingCompletionDestination.home,
    super.key,
  });
  static const path = '/onboarding-welcome';
  final String fullName;
  final int userId;

  /// Welcome 完成后的最终页面。
  final OnboardingCompletionDestination completionDestination;

  /// 构造包含姓名的欢迎页地址。
  static String location(
    String fullName,
    int userId, [
    OnboardingCompletionDestination completionDestination =
        OnboardingCompletionDestination.home,
  ]) => Uri(
    path: path,
    queryParameters: {
      'name': fullName,
      'userId': userId.toString(),
      if (completionDestination == OnboardingCompletionDestination.shop)
        'destination': 'shop',
    },
  ).toString();

  @override
  ConsumerState<OnboardingWelcomePage> createState() =>
      _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends ConsumerState<OnboardingWelcomePage> {
  bool _isCompleting = false;

  Future<void> _completeWelcome() async {
    if (_isCompleting) return;
    unawaited(
      ref.report(
        AnalyticsEvent.startJourney,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.welcome.value,
        },
      ),
    );
    if (widget.userId <= 0) {
      BotToast.showText(text: 'Unable to identify the current user.');
      return;
    }
    setState(() => _isCompleting = true);
    EasyLoading.show();
    try {
      final repository = await ref.read(
        welcomeCompletionRepositoryProvider.future,
      );
      await repository.markCompleted(widget.userId);
      if (!mounted) return;
      context.go(
        widget.completionDestination == OnboardingCompletionDestination.shop
            ? '${HomePage.path}?tab=shop'
            : HomePage.path,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      BotToast.showText(text: 'Unable to continue. Please try again.');
    } finally {
      EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedName = widget.fullName.trim();
    final notificationPermission = ref.watch(appNotificationPermissionProvider);
    final shouldShowReminder = notificationPermission.maybeWhen(
      data: (state) => !state.isEnabled,
      orElse: () => false,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF008BC7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
          child: Column(
            children: [
              Image.asset(
                'assets/images/nalo_logo_temp.png',
                width: 88,
                height: 70,
                fit: BoxFit.contain,
                color: const Color(0xFFFDDA7C),
                colorBlendMode: BlendMode.srcIn,
              ),
              const SizedBox(height: 32),
              Text(
                normalizedName.isEmpty
                    ? 'Welcome.'
                    : 'Welcome,\n$normalizedName.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'High or low, either way, '),
                    TextSpan(
                      text: 'you know.',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (shouldShowReminder)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/icons/notification_bell_blue.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Turn on reminders',
                              style: TextStyle(
                                color: Color(0xFF1A2433),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'We will remind you to take each test on time so your cycle stays valid.',
                              style: TextStyle(
                                color: Color(0xFF9FA89E),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                unawaited(
                                  ref.report(
                                    AnalyticsEvent.notificationEnableClick,
                                    properties: {
                                      AnalyticsEventProperty.pageName:
                                          AnalyticsPageName.welcome.value,
                                    },
                                  ),
                                );
                                unawaited(
                                  ref
                                      .read(
                                        appNotificationPermissionProvider
                                            .notifier,
                                      )
                                      .openSettings(),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                foregroundColor: const Color(0xFF008BC7),
                                overlayColor: Colors.transparent,
                              ),
                              child: const Text(
                                'Enable notifications',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  decorationColor: Color(0xFF008BC7),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isCompleting ? null : _completeWelcome,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFDDA7C),
                    foregroundColor: const Color(0xFF1A2433),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'Start your Nalo journey',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
