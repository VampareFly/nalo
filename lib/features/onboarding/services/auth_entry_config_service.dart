// 读取登录入口需要的公开配置，不依赖用户会话。
// Repository 将服务端开关写入本地缓存，页面只消费最终显示状态。

import 'package:nalo/core/network/api_client.dart';

/// 登录入口的服务端显示配置。
class AuthEntryConfig {
  const AuthEntryConfig({required this.showAppleLogin});

  final bool showAppleLogin;

  /// 从 configs/list 的 data 解析 Apple 登录开关。
  factory AuthEntryConfig.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException('The auth config data is invalid.');
    }
    final value = data['show_apple_login'];
    if (value != 0 && value != 1) {
      throw const ResponseFormatException('The Apple login config is invalid.');
    }
    return AuthEntryConfig(showAppleLogin: value == 1);
  }
}

/// 请求未登录状态下可访问的配置接口。
class AuthEntryConfigService {
  const AuthEntryConfigService(this._apiClient);

  final ApiClient _apiClient;

  /// 获取服务端最新的 Apple 登录显示开关。
  Future<AuthEntryConfig> fetch() async {
    final config = await _apiClient.get<AuthEntryConfig>(
      '/api/v1/app/configs/list',
      decoder: AuthEntryConfig.fromJson,
      requiresAuth: false,
    );
    if (config == null) {
      throw const ResponseFormatException('The auth config data is empty.');
    }
    return config;
  }
}
