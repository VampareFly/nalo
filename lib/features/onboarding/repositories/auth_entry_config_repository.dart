// 管理 Apple 登录开关的永久缓存与远端刷新。
// 无缓存时监听离线到在线变化补试；仅有效的服务端响应覆盖缓存。

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';
import 'package:nalo/features/onboarding/services/auth_entry_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _showAppleLoginKey = 'auth_show_apple_login';

/// App 启动时读取 Apple 登录缓存；首次安装无缓存时默认显示。
bool readInitialShowAppleLogin(SharedPreferences preferences) =>
    preferences.getBool(_showAppleLoginKey) ?? true;

/// 提供登录页首帧使用的 Apple 登录显示状态，由启动入口注入缓存值。
final initialShowAppleLoginProvider = Provider<bool>((ref) => true);

/// 为登录入口提供缓存值和最新远端配置。
class AuthEntryConfigRepository {
  const AuthEntryConfigRepository(this._service, this._preferences);

  final AuthEntryConfigService _service;
  final SharedPreferences _preferences;

  /// 读取永久缓存；返回 null 表示首次安装尚无服务端配置。
  bool? readCachedShowAppleLogin() => _preferences.getBool(_showAppleLoginKey);

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

/// 每次进入登录页先展示缓存或默认值；无缓存且恢复联网时补试。
final showAppleLoginProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final repository = await ref.watch(authEntryConfigRepositoryProvider.future);
  final cachedValue = repository.readCachedShowAppleLogin();
  yield cachedValue ?? ref.read(initialShowAppleLoginProvider);

  // 有缓存时只做本次进入的正常刷新，不保持网络状态监听。
  if (cachedValue != null) {
    try {
      yield await repository.refreshShowAppleLogin();
    } catch (_) {
      // 配置不可用时保留已有缓存。
    }
    return;
  }

  // 首次安装先订阅网络变化，避免系统权限弹窗期间漏掉离线到在线事件。
  final connectivity = Connectivity();
  final connectivityEvents = StreamController<List<ConnectivityResult>>();
  final subscription = connectivity.onConnectivityChanged.listen(
    connectivityEvents.add,
    onError: (Object _) {
      // 网络状态监听异常不影响登录页，首次请求仍会独立进行。
    },
  );
  try {
    bool wasOnline;
    try {
      wasOnline = _hasNetwork(await connectivity.checkConnectivity());
    } catch (_) {
      wasOnline = false;
    }

    try {
      yield await repository.refreshShowAppleLogin();
      return;
    } catch (_) {
      // 首次请求失败时保持默认显示，等待真实的网络状态变化。
    }

    await for (final results in connectivityEvents.stream) {
      final isOnline = _hasNetwork(results);
      if (!wasOnline && isOnline) {
        try {
          yield await repository.refreshShowAppleLogin();
          return;
        } catch (_) {
          // 连上网络不代表接口可达；等待下一次离线到在线变化。
        }
      }
      wasOnline = isOnline;
    }
  } finally {
    await subscription.cancel();
    await connectivityEvents.close();
  }
});

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);
