// 管理新登录注册入口页的正式服务端认证状态。
// 客户端直连 Shopify 的临时测试状态仍由 ShopifyAuthViewModel 独立管理。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/repositories/shopify_backend_auth_repository.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';

/// 登录注册入口页状态。
class AuthEntryState {
  const AuthEntryState({this.isLoading = false, this.errorMessage});

  final bool isLoading;

  final String? errorMessage;
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
      final repository = await ref.read(
        shopifyBackendAuthRepositoryProvider.future,
      );
      final result = await repository.authorize(intent);
      ref.read(authSessionProvider.notifier).markAuthenticated(result.token);
      state = const AuthEntryState();
      return result;
    } on FlutterAppAuthUserCancelledException {
      state = const AuthEntryState(errorMessage: 'Shopify login was cancelled');
      return null;
    } on ApiException catch (error) {
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on SessionExpiredException catch (error) {
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on NetworkException catch (error) {
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on ResponseFormatException catch (error) {
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on FlutterAppAuthPlatformException catch (error) {
      state = AuthEntryState(
        errorMessage: error.message ?? 'Unable to log in with Shopify',
      );
      return null;
    } catch (_) {
      state = const AuthEntryState(
        errorMessage: 'Unable to log in with Shopify',
      );
      return null;
    } finally {
      if (state.isLoading) state = const AuthEntryState();
    }
  }
}

/// 提供登录注册入口页 ViewModel。
final authEntryViewModelProvider =
    NotifierProvider.autoDispose<AuthEntryViewModel, AuthEntryState>(
      AuthEntryViewModel.new,
    );
