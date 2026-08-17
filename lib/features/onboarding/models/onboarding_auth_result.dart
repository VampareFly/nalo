// 定义服务端完成 Shopify 认证后，客户端需要进入的流程节点。

import 'package:nalo/features/auth/auth_token.dart';

/// Shopify 认证成功后的页面分流。
enum OnboardingAuthDestination { accountProfile, welcome, home, shop }

/// Profile 和 Welcome 全部完成后的最终页面。
enum OnboardingCompletionDestination { home, shop }

/// 服务端认证结果中供引导流程使用的数据。
class OnboardingAuthResult {
  const OnboardingAuthResult({
    required this.destination,
    required this.completionDestination,
    required this.token,
    required this.userId,
    this.email,
    this.fullName,
  });

  final OnboardingAuthDestination destination;

  /// 引导页全部完成后应进入的业务页面。
  final OnboardingCompletionDestination completionDestination;
  final AuthToken token;
  final int userId;
  final String? email;
  final String? fullName;
}
