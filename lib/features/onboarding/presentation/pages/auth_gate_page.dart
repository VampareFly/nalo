// 应用冷启动认证门，根据 Session、本地用户快照和 Welcome 状态分流。
// Token 生命周期由 AuthSessionNotifier 管理，启动分流不请求 user/info。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/repositories/welcome_completion_repository.dart';

class _AuthGateDestination {
  const _AuthGateDestination(this.location);

  final String location;
}

final _authGateDestinationProvider = FutureProvider<_AuthGateDestination?>((
  ref,
) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session.status == AuthSessionStatus.sessionExpired) return null;
  if (session.status == AuthSessionStatus.unauthenticated) {
    return const _AuthGateDestination(AuthEntryPage.path);
  }
  final userStorage = await ref.watch(currentUserStorageProvider.future);
  final user = await userStorage.read();
  if (user == null) {
    return const _AuthGateDestination(AuthEntryPage.path);
  }
  final welcomeRepository = await ref.watch(
    welcomeCompletionRepositoryProvider.future,
  );
  return _AuthGateDestination(
    !user.isProfileCompleted
        ? AccountProfilePage.location(user.email ?? '', user.id)
        : welcomeRepository.isCompleted(user.id)
        ? HomePage.path
        : OnboardingWelcomePage.location(user.fullName ?? '', user.id),
  );
});

/// 监听认证 Session，并在冷启动后执行一次无动画分流。
class AuthGatePage extends ConsumerWidget {
  const AuthGatePage({super.key});

  static const path = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(_authGateDestinationProvider);
    destination.whenData((value) {
      if (value == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go(value.location);
      });
    });
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8E0),
      body: destination.hasError
          ? Center(
              child: FilledButton(
                onPressed: () => ref.invalidate(_authGateDestinationProvider),
                child: const Text('Try again'),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
