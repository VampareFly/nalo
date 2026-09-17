// 管理 Apple 登录开关的永久缓存与远端刷新。
// 仅有效的服务端 0/1 响应能覆盖缓存，网络失败保留原显示状态。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';
import 'package:nalo/features/onboarding/services/auth_entry_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 为登录入口提供缓存值和最新远端配置。
class AuthEntryConfigRepository {
  const AuthEntryConfigRepository(this._service, this._preferences);

  static const _showAppleLoginKey = 'auth_show_apple_login';

  final AuthEntryConfigService _service;
  final SharedPreferences _preferences;

  /// 读取永久缓存；首次安装默认显示 Apple 登录。
  bool readShowAppleLogin() =>
      _preferences.getBool(_showAppleLoginKey) ?? true;

  /// 请求最新开关，并仅在有效响应时覆盖缓存。
  Future<bool> refreshShowAppleLogin() async {
    final config = await _service.fetch();
    await _preferences.setBool(_showAppleLoginKey, config.showAppleLogin);
    return config.showAppleLogin;
  }
}

/// 提供登录页专用配置仓库，不依赖检测模块。
final authEntryConfigRepositoryProvider = FutureProvider.autoDispose<
    AuthEntryConfigRepository
>((ref) async {
  final client = await ref.watch(businessApiClientProvider.future);
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return AuthEntryConfigRepository(
    AuthEntryConfigService(client),
    preferences,
  );
});

/// 每次进入登录页先展示缓存或默认值，再用服务端值更新 UI。
final showAppleLoginProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final repository = await ref.watch(authEntryConfigRepositoryProvider.future);
  yield repository.readShowAppleLogin();
  try {
    yield await repository.refreshShowAppleLogin();
  } catch (_) {
    // 配置不可用时保持缓存或首次安装默认值，不影响现有登录入口。
  }
});
