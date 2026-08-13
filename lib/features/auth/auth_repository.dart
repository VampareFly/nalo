// 编排登录、刷新和本地 Token 持久化。
// ViewModel 和会话 Provider 只依赖 Repository，不直接操作网络或存储。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/auth/auth_service.dart';
import 'package:tester_kit/features/auth/auth_token.dart';
import 'package:tester_kit/features/auth/token_storage.dart';

/// 编排认证请求、Token 映射和本地持久化。
class AuthRepository {
  const AuthRepository({
    required AuthService service,
    required TokenStorage tokenStorage,
  }) : _service = service,
       _tokenStorage = tokenStorage;

  final AuthService _service;
  final TokenStorage _tokenStorage;

  /// 邮箱登录成功后保存完整 Token。
  Future<AuthToken> login({
    required String email,
    required String password,
  }) async {
    final token = (await _service.login(
      email: email,
      password: password,
    )).toModel();
    await _tokenStorage.save(token);
    return token;
  }

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
  Future<void> clearSession() => _tokenStorage.clear();
}

/// 注入认证 Repository。
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  return AuthRepository(
    service: await ref.watch(authServiceProvider.future),
    tokenStorage: await ref.watch(tokenStorageProvider.future),
  );
});
