// 封装 Shopify Mobile/Public Client 的授权、客户端换令牌和服务端参数交接。
// AppAuth 负责 PKCE 与 App Callback，Dio 仅用于现有直连测试的令牌请求。

import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/dio_provider.dart';

/// 负责 Shopify OAuth 授权、令牌交换和退出登录请求。
class ShopifyAuthService {
  ShopifyAuthService({required Dio dio, FlutterAppAuth? appAuth})
    : _dio = dio,
      _appAuth = appAuth ?? const FlutterAppAuth();

  static const _clientId = '0ebf6c9c-5e1c-463b-b374-754a98a97f36';
  // TODO: <pf> 客户端直连 Shopify 测试入口删除时一并删除固定回调地址。
  static const _directTestRedirectUrl =
      'shop.69330108529.testerkit://oauth/callback';
  static const _discoveryUrl =
      'https://test-store-001-55rykspg.myshopify.com/'
      '.well-known/openid-configuration';
  static const _scopes = <String>[
    'openid',
    'email',
    'customer-account-api:full',
  ];

  final Dio _dio;
  final FlutterAppAuth _appAuth;

  /// 发起 Shopify OAuth 登录并交换访问令牌。
  Future<ShopifyAuthResult> login() async {
    final authorization = await authorizeForBackend();

    final discovery = await _getDiscoveryConfiguration();
    final tokenEndpoint = discovery['token_endpoint'] as String?;
    if (tokenEndpoint == null || tokenEndpoint.isEmpty) {
      throw const ShopifyAuthException(
        'Shopify authentication configuration is missing the token endpoint',
      );
    }

    final tokenResponse = await _dio.post<Map<String, dynamic>>(
      tokenEndpoint,
      data: {
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'redirect_uri': _directTestRedirectUrl,
        'code': authorization.authorizationCode,
        'code_verifier': authorization.codeVerifier,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: const {'User-Agent': 'Nalo/1.0'},
      ),
    );

    final data = tokenResponse.data;
    final accessToken = data?['access_token'] as String?;
    final idToken = data?['id_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const ShopifyAuthException(
        'Shopify login completed without an access token',
      );
    }
    if (idToken == null || idToken.isEmpty) {
      throw const ShopifyAuthException(
        'Shopify login completed without an ID token',
      );
    }

    final expiresIn = data?['expires_in'];
    final expiresInSeconds = switch (expiresIn) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };

    return ShopifyAuthResult(
      accessToken: accessToken,
      idToken: idToken,
      accessTokenExpirationDateTime: expiresInSeconds == null
          ? null
          : DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );
  }

  /// 完成 Shopify 授权并返回交给服务端换取令牌所需的参数。
  Future<ShopifyAuthorizationResult> authorizeForBackend({
    String? clientId,
    String? shopId,
    String? redirectUri,
    String? scope,
  }) async {
    final usesBackendPreparation =
        clientId != null &&
        shopId != null &&
        redirectUri != null &&
        scope != null;
    final authorizationEndpoint = Uri(
      scheme: 'https',
      host: 'shopify.com',
      pathSegments: ['authentication', shopId ?? '', 'oauth', 'authorize'],
    ).toString();
    final tokenEndpoint = Uri(
      scheme: 'https',
      host: 'shopify.com',
      pathSegments: ['authentication', shopId ?? '', 'oauth', 'token'],
    ).toString();
    final serviceConfiguration = usesBackendPreparation
        ? AuthorizationServiceConfiguration(
            authorizationEndpoint: authorizationEndpoint,
            tokenEndpoint: tokenEndpoint,
          )
        : null;
    final authorization = await _appAuth.authorize(
      AuthorizationRequest(
        clientId ?? _clientId,
        redirectUri ?? _directTestRedirectUrl,
        discoveryUrl: usesBackendPreparation ? null : _discoveryUrl,
        serviceConfiguration: serviceConfiguration,
        scopes: scope == null
            ? _scopes
            : scope
                  .split(RegExp(r'\s+'))
                  .where((item) => item.isNotEmpty)
                  .toList(),
      ),
    );

    final authorizationCode = authorization.authorizationCode;
    final codeVerifier = authorization.codeVerifier;
    if (authorizationCode == null || codeVerifier == null) {
      throw const ShopifyAuthException(
        'Shopify authorization completed without the required code',
      );
    }

    return ShopifyAuthorizationResult(
      authorizationCode: authorizationCode,
      codeVerifier: codeVerifier,
    );
  }

  /// 使用 ID Token 请求 Shopify 退出登录。
  Future<void> logout({required String idToken}) async {
    final discovery = await _getDiscoveryConfiguration();
    final endSessionEndpoint = discovery['end_session_endpoint'] as String?;
    if (endSessionEndpoint == null || endSessionEndpoint.isEmpty) {
      throw const ShopifyAuthException(
        'Shopify authentication configuration is missing the logout endpoint',
      );
    }

    await _dio.get<void>(
      endSessionEndpoint,
      queryParameters: {'id_token_hint': idToken},
      options: Options(headers: const {'User-Agent': 'Nalo/1.0'}),
    );
  }

  Future<Map<String, dynamic>> _getDiscoveryConfiguration() async {
    final response = await _dio.get<Map<String, dynamic>>(_discoveryUrl);
    final data = response.data;
    if (data == null) {
      throw const ShopifyAuthException(
        'Unable to load Shopify authentication configuration',
      );
    }
    return data;
  }
}

/// 注入项目复用的 Shopify AppAuth Service。
final shopifyAuthServiceProvider = Provider<ShopifyAuthService>(
  (ref) => ShopifyAuthService(dio: ref.watch(dioProvider)),
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

/// Shopify 登录成功后返回的令牌信息。
class ShopifyAuthResult {
  const ShopifyAuthResult({
    required this.accessToken,
    required this.idToken,
    required this.accessTokenExpirationDateTime,
  });

  final String accessToken;
  final String idToken;
  final DateTime? accessTokenExpirationDateTime;
}

/// Shopify OAuth 流程中的业务异常。
class ShopifyAuthException implements Exception {
  const ShopifyAuthException(this.message);

  final String message;
}
