// 定义 Token 本地存储边界及当前 SharedPreferences 实现。
// 上层依赖 TokenStorage，后续可替换为平台安全存储而不影响认证流程。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tester_kit/core/storage/shared_preferences_provider.dart';
import 'package:tester_kit/features/auth/auth_token.dart';

/// 隔离认证 Token 的本地存储实现。
abstract interface class TokenStorage {
  /// 读取完整 Token；任一字段缺失时返回 null。
  Future<AuthToken?> read();

  /// 原子语义地保存完整 Token。
  Future<void> save(AuthToken token);

  /// 删除全部本地认证数据。
  Future<void> clear();
}

/// 基于 SharedPreferences 的 TokenStorage 实现。
class PreferencesTokenStorage implements TokenStorage {
  const PreferencesTokenStorage(this._preferences);

  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _expiresAtKey = 'auth_expires_at';

  final SharedPreferences _preferences;

  @override
  Future<AuthToken?> read() async {
    final accessToken = _preferences.getString(_accessTokenKey);
    final refreshToken = _preferences.getString(_refreshTokenKey);
    final expiresAtValue = _preferences.getString(_expiresAtKey);
    final expiresAt = expiresAtValue == null
        ? null
        : DateTime.tryParse(expiresAtValue)?.toUtc();
    if (accessToken == null || refreshToken == null || expiresAt == null) {
      return null;
    }
    return AuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> save(AuthToken token) async {
    await Future.wait([
      _preferences.setString(_accessTokenKey, token.accessToken),
      _preferences.setString(_refreshTokenKey, token.refreshToken),
      _preferences.setString(
        _expiresAtKey,
        token.expiresAt.toUtc().toIso8601String(),
      ),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _preferences.remove(_accessTokenKey),
      _preferences.remove(_refreshTokenKey),
      _preferences.remove(_expiresAtKey),
    ]);
  }
}

/// 提供当前阶段使用的 SharedPreferences Token 存储。
final tokenStorageProvider = FutureProvider<TokenStorage>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return PreferencesTokenStorage(preferences);
});
