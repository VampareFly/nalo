// 隔离 Flutter 与 Nalo 服务端之间的 Shopify 认证协议。
// 服务端接口确定后只替换此层，不让授权细节进入 ViewModel 或页面。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';

/// 用户从入口页发起认证时的意图。
enum ShopifyAuthIntent { loginOrSignUp, signIn, kitPurchase }

/// 通过 Nalo 服务端完成 Shopify 登录注册认证。
class ShopifyBackendAuthService {
  const ShopifyBackendAuthService(this._apiClient);

  final ApiClient _apiClient;

  /// 创建一次性 Shopify OAuth attempt。
  Future<ShopifyAuthPreparation> prepare() async {
    final preparation = await _apiClient.post<ShopifyAuthPreparation>(
      '/api/v1/app/auth/shopify/prepare',
      decoder: _decodePreparation,
      requiresAuth: false,
    );
    if (preparation == null) {
      throw const ResponseFormatException(
        'The Shopify prepare response is empty.',
      );
    }
    return preparation;
  }

  /// 将 AppAuth 返回的授权参数兑换为 Nalo App Session。
  Future<ShopifyExchangeSession> exchange({
    required String code,
    required String codeVerifier,
    required String authAttemptId,
  }) async {
    final session = await _apiClient.post<ShopifyExchangeSession>(
      '/api/v1/app/auth/shopify/exchange',
      data: {
        'code': code,
        'code_verifier': codeVerifier,
        'auth_attempt_id': authAttemptId,
      },
      decoder: _decodeSession,
      requiresAuth: false,
    );
    if (session == null) {
      throw const ResponseFormatException(
        'The Shopify exchange response is empty.',
      );
    }
    return session;
  }

  ShopifyAuthPreparation _decodePreparation(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException(
        'The Shopify preparation data is not an object.',
      );
    }
    return ShopifyAuthPreparation.fromJson(data);
  }

  ShopifyExchangeSession _decodeSession(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException(
        'The Shopify exchange data is not an object.',
      );
    }
    return ShopifyExchangeSession.fromJson(data);
  }
}
