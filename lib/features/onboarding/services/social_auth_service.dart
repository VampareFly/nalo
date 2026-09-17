// 封装 Flutter 与 Nalo 服务端之间的第三方登录协议。
// 当前仅接入 Apple，服务端响应复用现有 Token 和 User 数据结构。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/auth/auth_token.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';

/// Nalo 社交登录成功后返回的统一 Token 和用户信息。
class SocialLoginSession {
  const SocialLoginSession({required this.token, required this.user});

  final AuthTokenDto token;
  final AppUserInfo user;

  /// 从 social/login 的 data 对象解析登录结果。
  factory SocialLoginSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final user = json['user'];
    if (token is! Map<String, dynamic> || user is! Map<String, dynamic>) {
      throw const ResponseFormatException(
        'The social login response has no token or user.',
      );
    }
    return SocialLoginSession(
      token: AuthTokenDto.fromJson(token),
      user: AppUserInfo.fromJson(user),
    );
  }
}

/// 通过 Nalo 服务端完成第三方身份登录。
class SocialAuthService {
  const SocialAuthService(this._apiClient);

  final ApiClient _apiClient;

  /// 使用 Apple 身份 Token 兑换 Nalo App Session。
  Future<SocialLoginSession> loginWithApple({
    required String identityToken,
    required String authorizationCode,
  }) async {
    // TODO: <pf> 服务端支持 authorization_code 后，将 authorizationCode 加入请求体。
    final session = await _apiClient.post<SocialLoginSession>(
      '/api/v1/app/auth/social/login',
      data: {'provider': 'apple', 'id_token': identityToken},
      decoder: _decodeSession,
      requiresAuth: false,
    );
    if (session == null) {
      throw const ResponseFormatException('The Apple login response is empty.');
    }
    return session;
  }

  SocialLoginSession _decodeSession(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException(
        'The Apple login data is not an object.',
      );
    }
    return SocialLoginSession.fromJson(data);
  }
}
