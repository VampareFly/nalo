// 封装自有后端的 Token 刷新、退出和账号注销接口。
// Service 只负责请求协议和 DTO 解析，本地会话清理由 Repository 处理。

import 'package:nalo/core/network/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/auth/auth_token.dart';

/// 调用自有后端的 Token 刷新接口。
class AuthService {
  const AuthService(this._apiClient);

  final ApiClient _apiClient;

  /// 使用 Refresh Token 获取一组新 Token。
  Future<AuthTokenDto> refresh({required String refreshToken}) async {
    final token = await _apiClient.post<AuthTokenDto>(
      '/api/v1/app/auth/refresh',
      data: {'refresh_token': refreshToken},
      decoder: _decodeToken,
      requiresAuth: false,
    );
    if (token == null) {
      throw const ResponseFormatException(
        'The refresh response has no token data.',
      );
    }
    return token;
  }

  /// 通知服务端注销当前 App Session。
  Future<void> logout() async {
    await _apiClient.post<void>('/api/v1/app/auth/logout');
  }

  /// 永久注销当前登录账号。
  Future<void> deactivate() async {
    await _apiClient.post<void>('/api/v1/app/auth/deactivate');
  }

  AuthTokenDto _decodeToken(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException('The token data is not an object.');
    }
    return AuthTokenDto.fromJson(data);
  }
}

/// 注入自有后端认证 Service。
final authServiceProvider = FutureProvider<AuthService>((ref) async {
  return AuthService(await ref.watch(businessApiClientProvider.future));
});
