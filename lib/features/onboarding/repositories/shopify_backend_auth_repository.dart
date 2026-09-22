// 编排 Shopify完整授权、最近账号快捷 Refresh、Token保存和用户分流。
// 快捷凭证失效时转无痕授权，ViewModel只消费最终分流结果。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_business_code.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/auth/auth_service.dart';
import 'package:nalo/features/auth/auth_token.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/auth/last_shopify_account_storage.dart';
import 'package:nalo/features/auth/token_storage.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/services/shopify_auth_service.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';
import 'package:nalo/features/onboarding/services/user_profile_service.dart';
import 'package:nalo/features/onboarding/repositories/welcome_completion_repository.dart';

/// 完成 Shopify 服务端认证并生成页面分流结果。
class ShopifyBackendAuthRepository {
  const ShopifyBackendAuthRepository({
    required this._backendService,
    required this._shopifyService,
    required this._authService,
    required this._userProfileService,
    required this._tokenStorage,
    required this._currentUserStorage,
    required this._lastShopifyAccountStorage,
    required this._welcomeCompletionRepository,
  });

  final ShopifyBackendAuthService _backendService;
  final ShopifyAuthService _shopifyService;
  final AuthService _authService;
  final UserProfileService _userProfileService;
  final TokenStorage _tokenStorage;
  final CurrentUserStorage _currentUserStorage;
  final LastShopifyAccountStorage _lastShopifyAccountStorage;
  final WelcomeCompletionRepository _welcomeCompletionRepository;

  /// 按 prepare → AppAuth → exchange登录，默认使用隔离授权流程。
  Future<OnboardingAuthResult> authorize(
    ShopifyAuthIntent intent, {
    bool forceLogin = true,
  }) async {
    final preparation = await _backendService.prepare();
    final authorization = await _shopifyService.authorizeForBackend(
      clientId: preparation.clientId,
      shopId: preparation.shopId,
      redirectUri: preparation.redirectUri,
      scope: preparation.scope,
      forceLogin: forceLogin,
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
      final email = exchange.user.email;
      if (email != null) {
        await _lastShopifyAccountStorage.save(
          userId: exchange.user.id,
          email: email,
          refreshToken: token.refreshToken,
        );
      } else {
        await _lastShopifyAccountStorage.clear();
      }
    } catch (_) {
      // 最近账号仅用于快捷入口，写入失败不阻塞已完成的登录。
    }

    try {
      final user = exchange.user;
      final hasCompletedWelcome = _welcomeCompletionRepository.isCompleted(
        user.id,
      );
      // Kit 购买只作为独立的待办续接，不改变 App 登录后的正常分流。
      const completionDestination = OnboardingCompletionDestination.home;
      final destination = !user.isProfileCompleted
          ? OnboardingAuthDestination.accountProfile
          : !hasCompletedWelcome
          ? OnboardingAuthDestination.welcome
          : OnboardingAuthDestination.home;
      return OnboardingAuthResult(
        destination: destination,
        completionDestination: completionDestination,
        token: token,
        userId: user.id,
        shopifyCustomerId: user.shopifyCustomerId,
        loginProvider: user.loginProvider,
        email: user.email,
        fullName: user.fullName,
      );
    } catch (_) {
      await Future.wait([_tokenStorage.clear(), _currentUserStorage.clear()]);
      rethrow;
    }
  }

  /// 优先用最近账号 Refresh Token恢复 Session，失效时转无痕 Shopify授权。
  Future<OnboardingAuthResult> authorizeReturning(
    ShopifyAuthIntent intent,
  ) async {
    final account = _lastShopifyAccountStorage.read();
    if (account == null) return authorize(intent, forceLogin: true);

    late final AuthToken token;
    try {
      token = (await _authService.refresh(
        refreshToken: account.refreshToken,
      )).toModel();
    } on ApiException catch (error) {
      if (error.code != ApiBusinessCode.refreshTokenExpired &&
          error.code != ApiBusinessCode.invalidRefreshToken) {
        rethrow;
      }
      await Future.wait([
        _tokenStorage.clear(),
        _currentUserStorage.clear(),
        _lastShopifyAccountStorage.clear(),
      ]);
      return authorize(intent, forceLogin: true);
    }

    await _tokenStorage.save(token);
    try {
      await _lastShopifyAccountStorage.updateRefreshToken(
        userId: account.userId,
        refreshToken: token.refreshToken,
      );
    } catch (_) {
      await Future.wait([
        _tokenStorage.clear(),
        _currentUserStorage.clear(),
        _lastShopifyAccountStorage.clear(),
      ]);
      rethrow;
    }

    try {
      final user = await _userProfileService.getInfo();
      if (user.id != account.userId) {
        await Future.wait([
          _tokenStorage.clear(),
          _currentUserStorage.clear(),
          _lastShopifyAccountStorage.clear(),
        ]);
        throw const ResponseFormatException(
          'The refreshed Shopify account does not match the saved user.',
        );
      }
      await _currentUserStorage.save(user);
      return OnboardingAuthResult(
        destination: OnboardingAuthDestination.home,
        completionDestination: OnboardingCompletionDestination.home,
        token: token,
        userId: user.id,
        shopifyCustomerId: user.shopifyCustomerId,
        loginProvider: user.loginProvider,
        email: user.email,
        fullName: user.fullName,
      );
    } catch (_) {
      await Future.wait([
        _tokenStorage.clear(),
        _currentUserStorage.clear(),
      ]);
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
        authService: AuthService(apiClient),
        userProfileService: UserProfileService(apiClient),
        tokenStorage: await ref.watch(tokenStorageProvider.future),
        currentUserStorage: await ref.watch(currentUserStorageProvider.future),
        lastShopifyAccountStorage: await ref.watch(
          lastShopifyAccountStorageProvider.future,
        ),
        welcomeCompletionRepository: await ref.watch(
          welcomeCompletionRepositoryProvider.future,
        ),
      );
    });
