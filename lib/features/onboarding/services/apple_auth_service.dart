// 封装 iOS Sign in with Apple 原生授权。
// Repository 消费身份 Token；授权码先保留在内存中，等待服务端协议支持。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple 原生授权后返回的服务端认证凭证。
class AppleAuthorizationResult {
  const AppleAuthorizationResult({
    required this.identityToken,
    required this.authorizationCode,
  });

  final String identityToken;
  final String authorizationCode;
}

/// 发起 Apple 原生授权并提取认证凭证。
class AppleAuthService {
  const AppleAuthService();

  /// 请求 Apple ID 授权；身份 Token 缺失时终止登录。
  Future<AppleAuthorizationResult> authorize() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
    );
    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw const AppleIdentityTokenMissingException();
    }
    return AppleAuthorizationResult(
      identityToken: identityToken,
      authorizationCode: credential.authorizationCode,
    );
  }
}

/// Apple 授权成功但未返回身份 Token。
class AppleIdentityTokenMissingException implements Exception {
  const AppleIdentityTokenMissingException();
}

/// 提供 Apple 原生授权服务。
final appleAuthServiceProvider = Provider<AppleAuthService>(
  (ref) => const AppleAuthService(),
);
