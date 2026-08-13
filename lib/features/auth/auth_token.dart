// 认证接口与客户端共用的 Token 模型及后端字段映射。
// Service 解析 DTO，Repository 将其转换为统一的 AuthToken。

import 'package:tester_kit/core/network/api_client.dart';

/// 客户端使用的完整认证凭证及过期时间。
class AuthToken {
  const AuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is AuthToken &&
      accessToken == other.accessToken &&
      refreshToken == other.refreshToken &&
      expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, expiresAt);
}

/// 解析后端登录与刷新接口返回的 Token 字段。
class AuthTokenDto {
  const AuthTokenDto({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  /// 从服务端 data 对象创建 DTO。
  factory AuthTokenDto.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    final expiresIn = json['expires_in'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        expiresIn is! int) {
      throw const ResponseFormatException('The token response is invalid.');
    }
    return AuthTokenDto(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
    );
  }

  /// 转换为客户端统一使用的 Token 模型。
  AuthToken toModel() {
    // TODO: <pf> 后端 Token 过期字段确定后，调整过期时间解析规则。
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expiresIn * 1000,
      isUtc: true,
    );
    return AuthToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }
}
