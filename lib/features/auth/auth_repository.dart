// 编排 Token 刷新、账号操作和本地会话持久化。
// 会话 Provider 只依赖 Repository，不直接操作网络或存储。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/auth/auth_service.dart';
import 'package:nalo/features/auth/auth_token.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/auth/token_storage.dart';

/// 编排 Token 刷新和本地持久化。
class AuthRepository {
  const AuthRepository({
    required this._service,
    required this._tokenStorage,
    required this._currentUserStorage,
  });

  final AuthService _service;
  final TokenStorage _tokenStorage;
  final CurrentUserStorage _currentUserStorage;

  /// 刷新成功后替换完整 Token；失败时保留旧值。
  Future<AuthToken> refresh(AuthToken currentToken) async {
    final token = (await _service.refresh(
      refreshToken: currentToken.refreshToken,
    )).toModel();
    await _tokenStorage.save(token);
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

  /// 服务端注销成功后清除本地 Token 和当前用户快照。
  Future<void> deactivate() async {
    await _service.deactivate();
    await clearSession();
  }
}

/// 注入认证 Repository。
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  return AuthRepository(
    service: await ref.watch(authServiceProvider.future),
    tokenStorage: await ref.watch(tokenStorageProvider.future),
    currentUserStorage: await ref.watch(currentUserStorageProvider.future),
  );
});
