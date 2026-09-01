// 持久化冷启动分流所需的当前用户快照。
// exchange、user/info 和 user/update 成功后写入并广播；退出或 Session 失效时清除。

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 隔离当前用户快照的本地存储实现。
abstract interface class CurrentUserStorage {
  /// 读取冷启动分流所需的当前用户。
  Future<AppUserInfo?> read();

  /// 使用服务端最新 User 覆盖本地快照。
  Future<void> save(AppUserInfo user);

  /// 监听当前用户快照的后续变更，不包含初始值。
  Stream<AppUserInfo?> get changes;

  /// 清除当前用户快照，不处理按 userId 保存的 Welcome 状态。
  Future<void> clear();

  /// 释放快照变更流。
  void dispose();
}

/// 使用 SharedPreferences 保存非敏感用户分流快照。
class PreferencesCurrentUserStorage implements CurrentUserStorage {
  PreferencesCurrentUserStorage(this._preferences);

  static const _currentUserKey = 'auth_current_user';

  final SharedPreferences _preferences;
  final StreamController<AppUserInfo?> _changes =
      StreamController<AppUserInfo?>.broadcast();

  @override
  Stream<AppUserInfo?> get changes => _changes.stream;

  @override
  Future<AppUserInfo?> read() async {
    final value = _preferences.getString(_currentUserKey);
    if (value == null) return null;
    try {
      final json = jsonDecode(value);
      return json is Map<String, dynamic> ? AppUserInfo.fromJson(json) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AppUserInfo user) async {
    final didSave = await _preferences.setString(
      _currentUserKey,
      jsonEncode(user.toJson()),
    );
    if (!didSave) throw StateError('Unable to save the current user.');
    _changes.add(user);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_currentUserKey);
    _changes.add(null);
  }

  @override
  void dispose() => _changes.close();
}

/// 提供当前用户快照的本地存储边界。
final currentUserStorageProvider = FutureProvider<CurrentUserStorage>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  final storage = PreferencesCurrentUserStorage(preferences);
  ref.onDispose(storage.dispose);
  return storage;
});

/// 提供可响应的当前用户快照，存储更新后自动通知所有页面。
final currentUserSnapshotProvider = StreamProvider<AppUserInfo?>((ref) async* {
  final storage = await ref.watch(currentUserStorageProvider.future);
  yield await storage.read();
  yield* storage.changes;
});
