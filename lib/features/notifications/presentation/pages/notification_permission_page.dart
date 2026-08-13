import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/onboarding/presentation/widgets/onboarding_background.dart';
import 'package:nalo/features/onboarding/presentation/widgets/onboarding_button.dart';

class NotificationPermissionPage extends ConsumerWidget {
  const NotificationPermissionPage({super.key});

  static const path = '/notification-permission';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: OnboardingBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 4),
                const Text('🔔', style: TextStyle(fontSize: 50, height: 1)),
                const SizedBox(height: 24),
                const Text(
                  'Stay on track',
                  style: TextStyle(fontFamily: 'serif', fontSize: 36, fontStyle: FontStyle.italic, height: 1.1),
                ),
                const SizedBox(height: 18),
                const Text(
                  "We'll remind you when to test, when to record your result, "
                  'and share the occasional did-you-know to keep you motivated.',
                  style: TextStyle(color: Color(0xFF717277), fontSize: 17, height: 1.45),
                ),
                const SizedBox(height: 30),
                OnboardingButton(
                  label: 'Turn on notifications',
                  onPressed: () {
                    unawaited(ref.read(notificationPermissionServiceProvider).openAppSettings());
                  },
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(HomePage.path),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF717277),
                      overlayColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    child: const Text('Not now'),
                  ),
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
