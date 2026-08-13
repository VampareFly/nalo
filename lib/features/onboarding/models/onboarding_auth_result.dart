// 定义服务端完成 Shopify 认证后，客户端需要进入的流程节点。

/// Shopify 认证成功后的页面分流。
enum OnboardingAuthDestination { accountProfile, welcome, home }

/// 服务端认证结果中供引导流程使用的数据。
class OnboardingAuthResult {
  const OnboardingAuthResult({
    required this.destination,
    this.email,
    this.fullName,
  });

  final OnboardingAuthDestination destination;
  final String? email;
  final String? fullName;
}
