import 'package:nalo/core/network/api_client.dart';
// 封装自有后端的 Token 刷新接口。
// Service 只负责请求字段和 DTO 解析，持久化由 AuthRepository 处理。

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
      '/api/v1/auth/refresh',
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
