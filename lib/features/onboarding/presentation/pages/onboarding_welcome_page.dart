// 账号创建后的欢迎页，承接通知权限入口并结束登录注册流程。

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';

/// 展示个性化欢迎信息并进入首页。
class OnboardingWelcomePage extends ConsumerWidget {
  const OnboardingWelcomePage({required this.fullName, super.key});
  static const path = '/onboarding-welcome';
  final String fullName;

  /// 构造包含姓名的欢迎页地址。
  static String location(String fullName) => Uri(path: path, queryParameters: {'name': fullName}).toString();

  @override Widget build(BuildContext context, WidgetRef ref) {
    final normalizedName = fullName.trim();
    final firstName = normalizedName.isEmpty
        ? null
        : normalizedName.split(RegExp(r'\s+')).first;
    final notificationPermission = ref.watch(
      appNotificationPermissionProvider,
    );
    final shouldShowReminder = notificationPermission.maybeWhen(
      data: (state) => !state.isEnabled,
      orElse: () => false,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF008BC7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
          child: Column(children: [
            Image.asset(
              'assets/images/nalo_logo_temp.png',
              width: 88,
              height: 70,
              fit: BoxFit.contain,
              color: const Color(0xFFFDDA7C),
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(height: 32),
            Text(firstName == null || firstName.isEmpty ? 'Welcome.' : 'Welcome,\n$firstName.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 36, height: 1.1, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text.rich(TextSpan(children: [TextSpan(text: 'High or low, either way, '), TextSpan(text: 'you know.', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white))]), textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 32),
            if (shouldShowReminder)
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Image.asset('assets/icons/notification_bell_blue.png', width: 24, height: 24), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Turn on reminders', style: TextStyle(color: Color(0xFF1A2433), fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('We will remind you to take each test on time so your cycle stays valid.', style: TextStyle(color: Color(0xFF9FA89E), fontSize: 12, height: 1.35)), TextButton(onPressed: () { unawaited(ref.read(appNotificationPermissionProvider.notifier).openSettings()); }, style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: const Color(0xFF008BC7), overlayColor: Colors.transparent), child: const Text('Enable notifications', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700))) ]))])),
            const Spacer(),
            SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: () { // TODO: <pf> 服务端协议确认后保存欢迎流程完成状态。
              context.go(HomePage.path); }, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFDDA7C), foregroundColor: const Color(0xFF1A2433), shape: const StadiumBorder()), child: const Text('Start your Nalo journey', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]),
        ),
      ),
    );
  }
}
