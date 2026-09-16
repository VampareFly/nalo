// 为 Push Token 上送提供平台无关入口，并将 Flutter 平台映射为服务端枚举。
// Provider 只传入 FCM Token，不直接处理网络字段或平台字符串。

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/notifications/services/push_token_service.dart';

/// 负责补充当前平台并调用 Push Token Service。
class PushTokenRepository {
  const PushTokenRepository(this._service);

  final PushTokenService _service;

  /// 为 iOS 或 Android 上送当前 FCM Token。
  Future<void> registerToken(String fcmToken) {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => throw UnsupportedError('Push token registration is unsupported.'),
    };
    return _service.registerToken(fcmToken: fcmToken, platform: platform);
  }
}

/// 提供使用当前登录业务网络配置的 Push Token Repository。
final pushTokenRepositoryProvider = FutureProvider<PushTokenRepository>((
  ref,
) async {
  final apiClient = await ref.watch(businessApiClientProvider.future);
  return PushTokenRepository(PushTokenService(apiClient));
});
