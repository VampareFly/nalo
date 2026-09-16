// 调用 Push Token 业务接口，只负责组装已确认的请求字段。
// Repository 根据当前运行平台提供 platform，并在登录成功后发起同步。

import 'package:nalo/core/network/api_client.dart';

/// 封装 FCM Token 注册或更新请求。
class PushTokenService {
  const PushTokenService(this._apiClient);

  final ApiClient _apiClient;

  /// 将当前 App 实例的 FCM Token 与平台上送至服务端。
  Future<void> registerToken({
    required String fcmToken,
    required String platform,
  }) async {
    await _apiClient.post<void>(
      '/api/v1/app/push-tokens',
      data: {'fcm_token': fcmToken, 'platform': platform},
    );
  }
}
