// 编排 Apple 原生授权、Nalo 服务端登录、凭证持久化和登录后分流。
// authorizationCode 当前只从 Apple 获取，不上传服务端或写入本地。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/auth/token_storage.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/repositories/welcome_completion_repository.dart';
import 'package:nalo/features/onboarding/services/apple_auth_service.dart';
import 'package:nalo/features/onboarding/services/social_auth_service.dart';

/// 完成 Apple 登录并生成现有引导流程可消费的分流结果。
class AppleAuthRepository {
  const AppleAuthRepository({
    required this.appleAuthService,
    required this.socialAuthService,
    required this.tokenStorage,
    required this.currentUserStorage,
    required this.welcomeCompletionRepository,
  });

  final AppleAuthService appleAuthService;
  final SocialAuthService socialAuthService;
  final TokenStorage tokenStorage;
  final CurrentUserStorage currentUserStorage;
  final WelcomeCompletionRepository welcomeCompletionRepository;

  /// 按 Apple 授权 → 服务端登录 → 本地持久化完成一次登录。
  Future<OnboardingAuthResult> authorize() async {
    final authorization = await appleAuthService.authorize();
    final session = await socialAuthService.loginWithApple(
      identityToken: authorization.identityToken,
      authorizationCode: authorization.authorizationCode,
    );

    final token = session.token.toModel();
    await tokenStorage.save(token);
    try {
      await currentUserStorage.save(session.user);
    } catch (_) {
      // TODO: <pf> 明确用户快照写入失败时的产品处理方式。
    }

    try {
      final user = session.user;
      final hasCompletedWelcome = welcomeCompletionRepository.isCompleted(
        user.id,
      );
      final destination = !user.isProfileCompleted
          ? OnboardingAuthDestination.accountProfile
          : !hasCompletedWelcome
          ? OnboardingAuthDestination.welcome
          : OnboardingAuthDestination.home;
      return OnboardingAuthResult(
        destination: destination,
        completionDestination: OnboardingCompletionDestination.home,
        token: token,
        userId: user.id,
        shopifyCustomerId: user.shopifyCustomerId,
        loginProvider: user.loginProvider,
        email: user.email,
        fullName: user.fullName,
      );
    } catch (_) {
      await Future.wait([tokenStorage.clear(), currentUserStorage.clear()]);
      rethrow;
    }
  }
}

/// 注入 Apple 登录 Repository 及其依赖。
final appleAuthRepositoryProvider = FutureProvider<AppleAuthRepository>((
  ref,
) async {
  final apiClient = await ref.watch(businessApiClientProvider.future);
  return AppleAuthRepository(
    appleAuthService: ref.watch(appleAuthServiceProvider),
    socialAuthService: SocialAuthService(apiClient),
    tokenStorage: await ref.watch(tokenStorageProvider.future),
    currentUserStorage: await ref.watch(currentUserStorageProvider.future),
    welcomeCompletionRepository: await ref.watch(
      welcomeCompletionRepositoryProvider.future,
    ),
  );
});
