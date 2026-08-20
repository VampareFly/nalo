// 按 Nalo 用户 ID 保存 Welcome 页面完成状态。
// 登录分流读取该状态，用户点击 Welcome 主按钮后写入完成标记。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';

/// 隔离 Welcome 完成状态的本地持久化细节。
class WelcomeCompletionRepository {
  const WelcomeCompletionRepository(this._preferences);

  final SharedPreferences _preferences;

  /// 查询指定用户是否已经完成 Welcome 页面。
  bool isCompleted(int userId) {
    try {
      return _preferences.getBool(_key(userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 在用户主动完成 Welcome 页面时写入本地标记。
  Future<void> markCompleted(int userId) async {
    final didSave = await _preferences.setBool(_key(userId), true);
    if (!didSave) {
      throw StateError('Unable to save the Welcome completion state.');
    }
  }

  /// 账号注销成功后删除该用户的 Welcome 完成标记。
  Future<void> clear(int userId) async {
    final didRemove = await _preferences.remove(_key(userId));
    if (!didRemove && _preferences.containsKey(_key(userId))) {
      throw StateError('Unable to clear the Welcome completion state.');
    }
  }

  String _key(int userId) => 'onboarding_welcome_completed_$userId';
}

/// 注入按用户隔离的 Welcome 本地状态 Repository。
final welcomeCompletionRepositoryProvider =
    FutureProvider<WelcomeCompletionRepository>((ref) async {
      final preferences = await ref.watch(sharedPreferencesProvider.future);
      return WelcomeCompletionRepository(preferences);
    });
