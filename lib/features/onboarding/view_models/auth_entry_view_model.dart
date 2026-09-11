// 管理新登录注册入口页的服务端 Shopify 认证状态。
// 完整认证结束后分别绑定 Amplitude 与 GA4 用户并上报结果。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:nalo/core/analytics/analytics.dart';
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
      final analytics = ref.read(analyticsProvider);
      await analytics.identifyUser(
        AnalyticsUserIdentity(
          appUserId: result.userId.toString(),
          shopifyCustomerId: result.shopifyCustomerId?.toString(),
        ),
        loginMethod: AnalyticsLoginMethod.shopify,
      );
      await _reportLoginResult(isSuccess: true);
      state = const AuthEntryState();
      return result;
    } on FlutterAppAuthUserCancelledException {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'oauth_cancelled: User cancelled Shopify authorization',
      );
      state = const AuthEntryState(errorMessage: 'Shopify login was cancelled');
      return null;
    } on ApiException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: '${error.code}: ${error.message}',
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on SessionExpiredException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'session_expired: ${error.message}',
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on NetworkException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: '${error.type.name}: ${error.message}',
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on ResponseFormatException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'response_format_error: ${error.message}',
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on FlutterAppAuthPlatformException catch (error) {
      final message = error.message ?? 'Unable to log in with Shopify';
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'oauth_error: $message',
      );
      state = AuthEntryState(errorMessage: message);
      return null;
    } catch (_) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'unknown_error: Unable to log in with Shopify',
      );
      state = const AuthEntryState(
        errorMessage: 'Unable to log in with Shopify',
      );
      return null;
    } finally {
      if (state.isLoading) state = const AuthEntryState();
    }
  }

  Future<void> _reportLoginResult({
    required bool isSuccess,
    String failReason = '',
  }) {
    return ref
        .read(analyticsProvider)
        .report(
          AnalyticsEvent.loginRequestResult,
          properties: {
            AnalyticsEventProperty.pageName:
                AnalyticsPageName.loginSignIn.value,
            AnalyticsEventProperty.loginMethod:
                AnalyticsLoginMethod.shopify.value,
            AnalyticsEventProperty.isSuccess: isSuccess ? 1 : 0,
            AnalyticsEventProperty.failReason: failReason,
          },
        );
  }
}

/// 提供登录注册入口页 ViewModel。
final authEntryViewModelProvider =
    NotifierProvider.autoDispose<AuthEntryViewModel, AuthEntryState>(
      AuthEntryViewModel.new,
    );
