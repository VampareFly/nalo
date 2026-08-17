// 定义 Nalo 服务端 Shopify OAuth 接口的数据模型。
// Service 负责 JSON 转换，Repository 使用这些模型编排授权和用户分流。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/auth/auth_token.dart';

/// prepare 接口创建的一次性 Shopify 授权配置。
class ShopifyAuthPreparation {
  const ShopifyAuthPreparation({
    required this.authAttemptId,
    required this.clientId,
    required this.shopId,
    required this.redirectUri,
    required this.scope,
  });

  final String authAttemptId;
  final String clientId;
  final String shopId;
  final String redirectUri;
  final String scope;

  /// 从 prepare 的 data 对象解析授权配置。
  factory ShopifyAuthPreparation.fromJson(Map<String, dynamic> json) {
    final authAttemptId = json['auth_attempt_id'];
    final clientId = json['client_id'];
    final shopId = json['shop_id'];
    final redirectUri = json['redirect_uri'];
    final scope = json['scope'];
    if (authAttemptId is! String ||
        authAttemptId.isEmpty ||
        clientId is! String ||
        clientId.isEmpty ||
        shopId is! String ||
        shopId.isEmpty ||
        redirectUri is! String ||
        Uri.tryParse(redirectUri)?.hasScheme != true ||
        scope is! String ||
        scope.isEmpty) {
      throw const ResponseFormatException(
        'The Shopify prepare response is invalid.',
      );
    }
    return ShopifyAuthPreparation(
      authAttemptId: authAttemptId,
      clientId: clientId,
      shopId: shopId,
      redirectUri: redirectUri,
      scope: scope,
    );
  }
}

/// exchange 接口签发的 Nalo App Session。
class ShopifyExchangeSession {
  const ShopifyExchangeSession({required this.token, required this.user});

  final AuthTokenDto token;

  /// exchange 同时返回的当前 Nalo 用户，用于登录后直接分流。
  final AppUserInfo user;

  /// 从 exchange 的 data 对象解析嵌套 Token 和 User。
  factory ShopifyExchangeSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final user = json['user'];
    if (token is! Map<String, dynamic> || user is! Map<String, dynamic>) {
      throw const ResponseFormatException(
        'The Shopify exchange response has no token or user.',
      );
    }
    return ShopifyExchangeSession(
      token: AuthTokenDto.fromJson(token),
      user: AppUserInfo.fromJson(user),
    );
  }
}

/// Nalo 用户资料及登录后页面分流所需字段。
class AppUserInfo {
  const AppUserInfo({
    required this.id,
    required this.isProfileCompleted,
    this.email,
    this.fullName,
    this.birthDay,
    this.gender,
  });

  final int id;

  /// 服务端确认的 Profile 完成状态，用于登录和冷启动分流。
  final bool isProfileCompleted;

  final String? email;
  final String? fullName;
  final String? birthDay;
  final int? gender;

  /// 从 user/info 的 data 对象解析当前已确认字段。
  factory AppUserInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final profileCompleted = json['is_profile_completed'];
    if (id is! int ||
        id <= 0 ||
        (profileCompleted != 0 && profileCompleted != 1)) {
      throw const ResponseFormatException('The user info response is invalid.');
    }
    return AppUserInfo(
      id: id,
      isProfileCompleted: profileCompleted == 1,
      email: json['email'] is String ? json['email'] as String : null,
      fullName: json['full_name'] is String
          ? json['full_name'] as String
          : null,
      birthDay: json['birth_day'] is String
          ? json['birth_day'] as String
          : null,
      gender: json['gender'] is int ? json['gender'] as int : null,
    );
  }
}
