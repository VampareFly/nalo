import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/app/config/app_config_provider.dart';
import 'package:tester_kit/features/home/presentation/pages/home_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/get_started_page.dart';

class LaunchPage extends ConsumerWidget {
  const LaunchPage({super.key});

  static const path = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      appConfigRepositoryProvider,
      (_, next) {
        next.whenData((repository) {
          context.go(
            repository.isFirstInstallation
                ? GetStartedPage.path
                : HomePage.path,
          );
        });
      },
    );

    return const Scaffold(body: SizedBox.expand());
  }
}
