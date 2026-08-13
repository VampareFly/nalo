// 隔离 Flutter 与 Nalo 服务端之间的 Shopify 认证协议。
// 服务端接口确定后只替换此层，不让授权细节进入 ViewModel 或页面。

import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';

/// 用户从入口页发起认证时的意图。
enum ShopifyAuthIntent { loginOrSignUp, signIn }

/// 通过 Nalo 服务端完成 Shopify 登录注册认证。
class ShopifyBackendAuthService {
  const ShopifyBackendAuthService();

  /// 发起服务端认证并返回下一步页面分流。
  Future<OnboardingAuthResult> authorize(ShopifyAuthIntent intent) async {
    // TODO: <pf> 服务端协议确认后接入授权地址、App Link 回调和结果查询。
    return const OnboardingAuthResult(
      destination: OnboardingAuthDestination.accountProfile,
      email: 'your@email.com',
    );
  }
}
