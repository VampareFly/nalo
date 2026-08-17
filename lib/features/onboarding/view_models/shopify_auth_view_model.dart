// 管理过渡期 Shopify 客户端直连登录和退出状态。
// 正式服务端认证由 AuthEntryViewModel 独立管理。

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/onboarding/services/shopify_auth_service.dart';

/// 提供 Shopify 测试认证流程的状态与操作入口。
final shopifyAuthViewModelProvider =
    NotifierProvider.autoDispose<ShopifyAuthViewModel, ShopifyAuthState>(
      ShopifyAuthViewModel.new,
    );

/// Shopify 登录流程的页面状态。
class ShopifyAuthState {
  const ShopifyAuthState({
    this.isLoading = false,
    this.isLoggingOut = false,
    this.accessToken,
    this.idToken,
    this.accessTokenExpirationDateTime,
  });

  final bool isLoading;
  final bool isLoggingOut;
  final String? accessToken;
  final String? idToken;
  final DateTime? accessTokenExpirationDateTime;

  bool get isLoggedIn => accessToken != null && idToken != null;
  bool get isBusy => isLoading || isLoggingOut;
}

/// 编排 Shopify 客户端直连登录和退出流程。
class ShopifyAuthViewModel extends Notifier<ShopifyAuthState> {
  @override
  ShopifyAuthState build() => const ShopifyAuthState();

  /// 登录成功后保存当前会话令牌。
  Future<String?> login() async {
    if (state.isBusy) return null;
    state = const ShopifyAuthState(isLoading: true);

    try {
      final result = await ref.read(shopifyAuthServiceProvider).login();
      state = ShopifyAuthState(
        accessToken: result.accessToken,
        idToken: result.idToken,
        accessTokenExpirationDateTime: result.accessTokenExpirationDateTime,
      );
      return null;
    } on FlutterAppAuthUserCancelledException {
      state = const ShopifyAuthState();
      return 'Shopify login was cancelled';
    } on ShopifyAuthException catch (error) {
      state = const ShopifyAuthState();
      return error.message;
    } on FlutterAppAuthPlatformException catch (error) {
      state = const ShopifyAuthState();
      return error.message ?? 'Unable to log in with Shopify';
    } catch (_) {
      state = const ShopifyAuthState();
      return 'Unable to log in with Shopify';
    }
  }

  /// 请求 Shopify 退出登录，失败时恢复原登录状态。
  Future<String?> logout() async {
    final idToken = state.idToken;
    if (idToken == null) return 'No active Shopify session';
    if (state.isBusy) return null;

    final authenticatedState = state;
    state = ShopifyAuthState(
      isLoggingOut: true,
      accessToken: state.accessToken,
      idToken: state.idToken,
      accessTokenExpirationDateTime: state.accessTokenExpirationDateTime,
    );

    try {
      await ref.read(shopifyAuthServiceProvider).logout(idToken: idToken);
      state = const ShopifyAuthState();
      return null;
    } on ShopifyAuthException catch (error) {
      state = authenticatedState;
      return error.message;
    } catch (_) {
      state = authenticatedState;
      return 'Unable to log out from Shopify';
    }
  }
}
