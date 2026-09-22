// 编排 Token 刷新、账号操作和本地会话持久化。
// 普通退出保留 Shopify 快捷登录凭证，注销时仅清除同一用户的凭证。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/auth/auth_service.dart';
import 'package:nalo/features/auth/auth_token.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/auth/last_shopify_account_storage.dart';
import 'package:nalo/features/auth/token_storage.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';

/// 编排 Token 刷新和本地持久化。
class AuthRepository {
  const AuthRepository({
    required this._service,
    required this._tokenStorage,
    required this._currentUserStorage,
    required this._lastShopifyAccountStorage,
  });

  final AuthService _service;
  final TokenStorage _tokenStorage;
  final CurrentUserStorage _currentUserStorage;
  final LastShopifyAccountStorage _lastShopifyAccountStorage;

  /// 仅在当前 Session 未变化时保存刷新结果；退出或重新登录后丢弃旧结果。
  Future<AuthToken?> refresh(AuthToken currentToken) async {
    final token = (await _service.refresh(
      refreshToken: currentToken.refreshToken,
    )).toModel();
    final storedToken = await _tokenStorage.read();
    if (storedToken != currentToken) return null;
    await _tokenStorage.save(token);
    final currentUser = await _currentUserStorage.read();
    if (currentUser?.loginProvider == LoginProvider.shopify) {
      try {
        await _lastShopifyAccountStorage.updateRefreshToken(
          userId: currentUser!.id,
          refreshToken: token.refreshToken,
        );
      } catch (_) {
        // 快捷凭证轮换失败不影响当前有效 Session的后台刷新结果。
      }
    }
    return token;
  }

  /// 读取本地完整 Token。
  Future<AuthToken?> readToken() => _tokenStorage.read();

  /// 清理当前认证会话。
  Future<void> clearSession() async {
    await Future.wait([_tokenStorage.clear(), _currentUserStorage.clear()]);
  }

  /// 请求服务端退出，并保证最终清理本地 Token。
  Future<void> logout() async {
    try {
      await _service.logout();
    } finally {
      await clearSession();
    }
  }

  /// 服务端注销成功后清除 Session，并仅清除属于当前用户的快捷凭证。
  Future<void> deactivate() async {
    final currentUser = await _currentUserStorage.read();
    await _service.deactivate();
    await clearSession();
    if (currentUser != null) {
      await _lastShopifyAccountStorage.clearIfUserId(currentUser.id);
    }
  }
}

/// 注入认证 Repository。
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  return AuthRepository(
    service: await ref.watch(authServiceProvider.future),
    tokenStorage: await ref.watch(tokenStorageProvider.future),
    currentUserStorage: await ref.watch(currentUserStorageProvider.future),
    lastShopifyAccountStorage: await ref.watch(
      lastShopifyAccountStorageProvider.future,
    ),
  );
});
