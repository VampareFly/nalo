// 定义 Nalo 服务端 Shopify OAuth 接口的数据模型。
// Service 负责 JSON 转换，Repository 使用这些模型编排授权、用户分流和 Profile 展示。

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
    this.testInfo,
    this.referralCard,
  });

  final int id;

  /// 服务端确认的 Profile 完成状态，用于登录和冷启动分流。
  final bool isProfileCompleted;

  final String? email;
  final String? fullName;
  final String? birthDay;
  final int? gender;

  /// Profile 展示使用的累计检测信息；接口缺失或格式异常时为空。
  final UserTestInfo? testInfo;

  /// Profile 展示使用的服务端 Referral 活动配置。
  final UserReferralCard? referralCard;

  /// 从 user/info 或 user/update 的 data 对象解析完整用户字段。
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
      testInfo: UserTestInfo.tryParse(json['test_info']),
      referralCard: UserReferralCard.tryParse(json['referral_card']),
    );
  }

  /// 转换为本地分流快照，字段名与服务端 User 保持一致。
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'birth_day': birthDay,
    'gender': gender,
    'is_profile_completed': isProfileCompleted ? 1 : 0,
    if (testInfo != null) 'test_info': testInfo!.toJson(),
    if (referralCard != null) 'referral_card': referralCard!.toJson(),
  };
}

/// 用户累计检测统计，用于 Profile 展示完成次数。
class UserTestInfo {
  const UserTestInfo({
    required this.sumCount,
    required this.cortisolCount,
    required this.testosteroneCount,
  });

  final int sumCount;
  final int cortisolCount;
  final int testosteroneCount;

  /// 安全解析 test_info；对象或字段异常时返回空并由 UI 降级为 0。
  static UserTestInfo? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final sumCount = _nonNegativeInt(value['sum_count']);
    if (sumCount == null) return null;
    return UserTestInfo(
      sumCount: sumCount,
      cortisolCount: _nonNegativeInt(value['cortisol_count']) ?? 0,
      testosteroneCount: _nonNegativeInt(value['testosterone_count']) ?? 0,
    );
  }

  /// 转换为本地用户快照字段。
  Map<String, dynamic> toJson() => {
    'sum_count': sumCount,
    'cortisol_count': cortisolCount,
    'testosterone_count': testosteroneCount,
  };

  static int? _nonNegativeInt(Object? value) =>
      value is int && value >= 0 ? value : null;
}

/// Profile Referral 卡片的服务端动态配置。
class UserReferralCard {
  const UserReferralCard({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.actionUrl,
    this.shareText,
  });

  final String title;
  final String description;
  final String buttonText;
  final String actionUrl;

  /// 系统分享时展示的服务端文案；缺失或为空时仅分享链接。
  final String? shareText;

  /// 解析 referral_card；任一必填字段为空时隐藏卡片。
  static UserReferralCard? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final title = _nonEmptyString(value['title']);
    final description = _nonEmptyString(value['description']);
    final buttonText = _nonEmptyString(value['button_text']);
    final actionUrl = _nonEmptyString(value['action_url']);
    if (title == null ||
        description == null ||
        buttonText == null ||
        actionUrl == null) {
      return null;
    }
    return UserReferralCard(
      title: title,
      description: description,
      buttonText: buttonText,
      actionUrl: actionUrl,
      shareText: _nonEmptyString(value['share_text']),
    );
  }

  /// 转换为本地用户快照字段。
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'button_text': buttonText,
    'action_url': actionUrl,
    if (shareText != null) 'share_text': shareText,
  };

  static String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
