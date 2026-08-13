// 管理新登录注册入口页的正式服务端认证状态。
// 客户端直连 Shopify 的临时测试状态仍由 ShopifyAuthViewModel 独立管理。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';

/// 注入 Nalo 服务端 Shopify 认证服务。
final shopifyBackendAuthServiceProvider = Provider<ShopifyBackendAuthService>(
  (ref) => const ShopifyBackendAuthService(),
);

/// 登录注册入口页状态。
class AuthEntryState {
  const AuthEntryState({this.isLoading = false});

  final bool isLoading;
}

/// 编排正式 Shopify 服务端认证并阻止重复提交。
class AuthEntryViewModel extends Notifier<AuthEntryState> {
  @override
  AuthEntryState build() => const AuthEntryState();

  /// 按入口意图发起服务端认证。
  Future<OnboardingAuthResult?> authorize(ShopifyAuthIntent intent) async {
    if (state.isLoading) return null;
    state = const AuthEntryState(isLoading: true);
    try {
      return await ref.read(shopifyBackendAuthServiceProvider).authorize(intent);
    } finally {
      state = const AuthEntryState();
    }
  }
}

/// 提供登录注册入口页 ViewModel。
final authEntryViewModelProvider =
    NotifierProvider.autoDispose<AuthEntryViewModel, AuthEntryState>(
      AuthEntryViewModel.new,
    );
