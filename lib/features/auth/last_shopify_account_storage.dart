// 持久化最近一次成功登录的 Shopify 快捷登录凭证。
// Shopify 登录成功时覆盖，普通退出时保留，仅注销同一用户时清除。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 最近一次成功登录的 Shopify 账号。
class LastShopifyAccount {
  const LastShopifyAccount({
    required this.userId,
    required this.maskedEmail,
    required this.refreshToken,
  });

  final int userId;
  final String maskedEmail;
  final String refreshToken;
}

/// 隔离最近 Shopify 账号展示信息的本地存储。
abstract interface class LastShopifyAccountStorage {
  /// 读取最近一次成功登录的 Shopify 账号。
  LastShopifyAccount? read();

  /// Shopify 登录成功后覆盖账号展示信息和快捷登录凭证。
  Future<void> save({
    required int userId,
    required String email,
    required String refreshToken,
  });

  /// Refresh 成功后仅轮换同一用户的快捷登录 Token。
  Future<void> updateRefreshToken({
    required int userId,
    required String refreshToken,
  });

  /// 监听最近账号的后续变化，不包含初始值。
  Stream<LastShopifyAccount?> get changes;

  /// 注销账号后清除最近账号。
  Future<void> clear();

  /// 仅在注销用户与快捷登录用户一致时清除凭证。
  Future<void> clearIfUserId(int userId);

  /// 释放账号变更流。
  void dispose();
}

/// 使用 SharedPreferences 保存最近 Shopify 账号展示信息。
class PreferencesLastShopifyAccountStorage
    implements LastShopifyAccountStorage {
  PreferencesLastShopifyAccountStorage(this._preferences);

  static const _maskedEmailKey = 'auth_last_shopify_account_masked_email';
  static const _userIdKey = 'auth_last_shopify_account_user_id';
  static const _refreshTokenKey = 'auth_last_shopify_account_refresh_token';

  final SharedPreferences _preferences;
  final StreamController<LastShopifyAccount?> _changes =
      StreamController<LastShopifyAccount?>.broadcast();

  @override
  Stream<LastShopifyAccount?> get changes => _changes.stream;

  @override
  LastShopifyAccount? read() {
    final maskedEmail = _preferences.getString(_maskedEmailKey)?.trim();
    final userId = _preferences.getInt(_userIdKey);
    final refreshToken = _preferences.getString(_refreshTokenKey)?.trim();
    if (maskedEmail == null ||
        maskedEmail.isEmpty ||
        userId == null ||
        userId <= 0 ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    return LastShopifyAccount(
      userId: userId,
      maskedEmail: maskedEmail,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> save({
    required int userId,
    required String email,
    required String refreshToken,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedRefreshToken = refreshToken.trim();
    if (userId <= 0 ||
        normalizedEmail.isEmpty ||
        normalizedRefreshToken.isEmpty) {
      return;
    }
    final maskedEmail = _maskEmail(normalizedEmail);
    // TODO: <pf> 接入 Keychain/Keystore 后将快捷登录 Refresh Token 迁移到安全存储。
    final results = await Future.wait([
      _preferences.setInt(_userIdKey, userId),
      _preferences.setString(_maskedEmailKey, maskedEmail),
      _preferences.setString(_refreshTokenKey, normalizedRefreshToken),
    ]);
    if (results.any((didSave) => !didSave)) {
      throw StateError('Unable to save the last Shopify account.');
    }
    _changes.add(
      LastShopifyAccount(
        userId: userId,
        maskedEmail: maskedEmail,
        refreshToken: normalizedRefreshToken,
      ),
    );
  }

  @override
  Future<void> updateRefreshToken({
    required int userId,
    required String refreshToken,
  }) async {
    final account = read();
    final normalizedRefreshToken = refreshToken.trim();
    if (account == null ||
        account.userId != userId ||
        normalizedRefreshToken.isEmpty) {
      return;
    }
    // TODO: <pf> 接入 Keychain/Keystore 后将快捷登录 Refresh Token 迁移到安全存储。
    final didSave = await _preferences.setString(
      _refreshTokenKey,
      normalizedRefreshToken,
    );
    if (!didSave) {
      throw StateError('Unable to update the last Shopify account.');
    }
    _changes.add(
      LastShopifyAccount(
        userId: account.userId,
        maskedEmail: account.maskedEmail,
        refreshToken: normalizedRefreshToken,
      ),
    );
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _preferences.remove(_userIdKey),
      _preferences.remove(_maskedEmailKey),
      _preferences.remove(_refreshTokenKey),
    ]);
    _changes.add(null);
  }

  @override
  Future<void> clearIfUserId(int userId) async {
    if (read()?.userId == userId) await clear();
  }

  @override
  void dispose() => _changes.close();

  String _maskEmail(String email) {
    final separatorIndex = email.indexOf('@');
    if (separatorIndex <= 0) return email;
    final localPart = email.substring(0, separatorIndex);
    final visibleLength = localPart.length < 3 ? localPart.length : 3;
    return '${localPart.substring(0, visibleLength)}***${email.substring(separatorIndex)}';
  }
}

/// 提供最近 Shopify 账号的本地存储边界。
final lastShopifyAccountStorageProvider =
    FutureProvider<LastShopifyAccountStorage>((ref) async {
      final preferences = await ref.watch(sharedPreferencesProvider.future);
      final storage = PreferencesLastShopifyAccountStorage(preferences);
      ref.onDispose(storage.dispose);
      return storage;
    });

/// 提供可响应的最近 Shopify 账号；退出登录后仍可用于快速登录。
final lastShopifyAccountProvider = StreamProvider<LastShopifyAccount?>((
  ref,
) async* {
  final storage = await ref.watch(lastShopifyAccountStorageProvider.future);
  yield storage.read();
  yield* storage.changes;
});
