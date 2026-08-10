import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

/// 负责 Shopify OAuth 登录、令牌交换和退出登录请求。
class ShopifyAuthService {
  ShopifyAuthService({required Dio dio, FlutterAppAuth? appAuth})
    : _dio = dio,
      _appAuth = appAuth ?? const FlutterAppAuth();

  static const _clientId = 'c05885f3-1a5a-474a-85fa-11b0a311dc00';
  static const _redirectUrl = 'shop.69330108529.testerkit://oauth/callback';
  static const _discoveryUrl =
      'https://test-store-001-55rykspg.myshopify.com/'
      '.well-known/openid-configuration';
  static const _scopes = <String>['openid', 'email', 'customer-account-api:full'];

  final Dio _dio;
  final FlutterAppAuth _appAuth;

  /// 发起 Shopify OAuth 登录并交换访问令牌。
  Future<ShopifyAuthResult> login() async {
    final authorization = await _appAuth.authorize(
      AuthorizationRequest(
        _clientId,
        _redirectUrl,
        discoveryUrl: _discoveryUrl,
        scopes: _scopes,
      ),
    );

    final authorizationCode = authorization.authorizationCode;
    final codeVerifier = authorization.codeVerifier;
    if (authorizationCode == null || codeVerifier == null) {
      throw const ShopifyAuthException(
        'Shopify authorization completed without the required code',
      );
    }

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
        'redirect_uri': _redirectUrl,
        'code': authorizationCode,
        'code_verifier': codeVerifier,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: const {'User-Agent': 'TesterKit/1.0'},
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

  /// 使用 ID Token 请求 Shopify 退出登录。
  Future<void> logout({required String idToken}) async {
    final discovery = await _getDiscoveryConfiguration();
    final endSessionEndpoint =
        discovery['end_session_endpoint'] as String?;
    if (endSessionEndpoint == null || endSessionEndpoint.isEmpty) {
      throw const ShopifyAuthException(
        'Shopify authentication configuration is missing the logout endpoint',
      );
    }

    await _dio.get<void>(
      endSessionEndpoint,
      queryParameters: {'id_token_hint': idToken},
      options: Options(headers: const {'User-Agent': 'TesterKit/1.0'}),
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
