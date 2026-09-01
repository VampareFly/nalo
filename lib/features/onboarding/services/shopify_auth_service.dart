// 封装服务端 Shopify 登录流程中的 AppAuth 授权步骤。
// prepare 参数由 Repository 传入，本服务只返回 exchange 所需的 code 和 verifier。

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_client.dart';

/// 使用服务端 prepare 参数完成 Shopify OAuth 授权。
class ShopifyAuthService {
  ShopifyAuthService({FlutterAppAuth? appAuth})
    : _appAuth = appAuth ?? const FlutterAppAuth();

  final FlutterAppAuth _appAuth;

  /// 完成 Shopify 授权并返回交给服务端换取令牌所需的参数。
  Future<ShopifyAuthorizationResult> authorizeForBackend({
    required String clientId,
    required String shopId,
    required String redirectUri,
    required String scope,
  }) async {
    final authorizationEndpoint = Uri(
      scheme: 'https',
      host: 'shopify.com',
      pathSegments: ['authentication', shopId, 'oauth', 'authorize'],
    ).toString();
    final tokenEndpoint = Uri(
      scheme: 'https',
      host: 'shopify.com',
      pathSegments: ['authentication', shopId, 'oauth', 'token'],
    ).toString();
    final authorization = await _appAuth.authorize(
      AuthorizationRequest(
        clientId,
        redirectUri,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: authorizationEndpoint,
          tokenEndpoint: tokenEndpoint,
        ),
        scopes: scope
            .split(RegExp(r'\s+'))
            .where((item) => item.isNotEmpty)
            .toList(),
      ),
    );

    final authorizationCode = authorization.authorizationCode;
    final codeVerifier = authorization.codeVerifier;
    if (authorizationCode == null || codeVerifier == null) {
      throw const ResponseFormatException(
        'Shopify authorization completed without the required code',
      );
    }

    return ShopifyAuthorizationResult(
      authorizationCode: authorizationCode,
      codeVerifier: codeVerifier,
    );
  }
}

/// 注入项目复用的 Shopify AppAuth Service。
final shopifyAuthServiceProvider = Provider<ShopifyAuthService>(
  (ref) => ShopifyAuthService(),
);

/// App 完成 Shopify 授权后需要提交给服务端的 OAuth 参数。
class ShopifyAuthorizationResult {
  const ShopifyAuthorizationResult({
    required this.authorizationCode,
    required this.codeVerifier,
  });

  final String authorizationCode;
  final String codeVerifier;
}
