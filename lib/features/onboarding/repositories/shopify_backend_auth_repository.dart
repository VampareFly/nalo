// 编排 Nalo prepare、Shopify AppAuth、exchange、Token 保存和用户分流。
// ViewModel 只消费最终分流结果，不接触 OAuth 参数或网络 DTO。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/auth/token_storage.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/services/shopify_auth_service.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';
import 'package:nalo/features/onboarding/repositories/welcome_completion_repository.dart';

/// 完成 Shopify 服务端认证并生成页面分流结果。
class ShopifyBackendAuthRepository {
  const ShopifyBackendAuthRepository({
    required this._backendService,
    required this._shopifyService,
    required this._tokenStorage,
    required this._currentUserStorage,
    required this._welcomeCompletionRepository,
  });

  final ShopifyBackendAuthService _backendService;
  final ShopifyAuthService _shopifyService;
  final TokenStorage _tokenStorage;
  final CurrentUserStorage _currentUserStorage;
  final WelcomeCompletionRepository _welcomeCompletionRepository;

  /// 按 prepare → AppAuth → exchange 完成一次登录并使用响应用户分流。
  Future<OnboardingAuthResult> authorize(ShopifyAuthIntent intent) async {
    final preparation = await _backendService.prepare();
    final authorization = await _shopifyService.authorizeForBackend(
      clientId: preparation.clientId,
      shopId: preparation.shopId,
      redirectUri: preparation.redirectUri,
      scope: preparation.scope,
    );
    final exchange = await _backendService.exchange(
      code: authorization.authorizationCode,
      codeVerifier: authorization.codeVerifier,
      authAttemptId: preparation.authAttemptId,
    );
    final token = exchange.token.toModel();
    await _tokenStorage.save(token);
    try {
      await _currentUserStorage.save(exchange.user);
    } catch (_) {
      // TODO: <pf> 明确用户快照写入失败时的产品处理方式。
    }

    try {
      final user = exchange.user;
      final hasCompletedWelcome = _welcomeCompletionRepository.isCompleted(
        user.id,
      );
      final completionDestination = intent == ShopifyAuthIntent.kitPurchase
          ? OnboardingCompletionDestination.shop
          : OnboardingCompletionDestination.home;
      final destination = !user.isProfileCompleted
          ? OnboardingAuthDestination.accountProfile
          : !hasCompletedWelcome
          ? OnboardingAuthDestination.welcome
          : completionDestination == OnboardingCompletionDestination.shop
          ? OnboardingAuthDestination.shop
          : OnboardingAuthDestination.home;
      return OnboardingAuthResult(
        destination: destination,
        completionDestination: completionDestination,
        token: token,
        userId: user.id,
        email: user.email,
        fullName: user.fullName,
      );
    } catch (_) {
      await Future.wait([_tokenStorage.clear(), _currentUserStorage.clear()]);
      rethrow;
    }
  }
}

/// 注入正式 Shopify 服务端认证 Repository。
final shopifyBackendAuthRepositoryProvider =
    FutureProvider<ShopifyBackendAuthRepository>((ref) async {
      final apiClient = await ref.watch(businessApiClientProvider.future);
      return ShopifyBackendAuthRepository(
        backendService: ShopifyBackendAuthService(apiClient),
        shopifyService: ref.watch(shopifyAuthServiceProvider),
        tokenStorage: await ref.watch(tokenStorageProvider.future),
        currentUserStorage: await ref.watch(currentUserStorageProvider.future),
        welcomeCompletionRepository: await ref.watch(
          welcomeCompletionRepositoryProvider.future,
        ),
      );
    });
