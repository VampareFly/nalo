// 管理登录注册入口页的 Shopify 与 Apple 服务端认证状态。
// 完整认证结束后分别绑定 Amplitude 与 GA4 用户并上报结果。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/repositories/apple_auth_repository.dart';
import 'package:nalo/features/onboarding/repositories/shopify_backend_auth_repository.dart';
import 'package:nalo/features/onboarding/services/apple_auth_service.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 登录注册入口页状态。
class AuthEntryState {
  const AuthEntryState({this.isLoading = false, this.errorMessage});

  final bool isLoading;

  final String? errorMessage;
}

/// 编排 Shopify 与 Apple 服务端认证并阻止重复提交。
class AuthEntryViewModel extends Notifier<AuthEntryState> {
  @override
  AuthEntryState build() => const AuthEntryState();

  /// 按入口意图发起 Shopify 认证，并以发起页面记录认证结果来源。
  Future<OnboardingAuthResult?> authorize(
    ShopifyAuthIntent intent, {
    AnalyticsPageName pageName = AnalyticsPageName.loginSignIn,
  }) async {
    return _authorize(
      request: () async {
        final repository = await ref.read(
          shopifyBackendAuthRepositoryProvider.future,
        );
        return repository.authorize(intent);
      },
      loginMethod: AnalyticsLoginMethod.shopify,
      providerName: 'Shopify',
      pageName: pageName,
    );
  }

  /// 发起 Apple 原生授权并通过 Nalo 服务端建立 Session。
  Future<OnboardingAuthResult?> authorizeApple() {
    return _authorize(
      request: () async {
        final repository = await ref.read(appleAuthRepositoryProvider.future);
        return repository.authorize();
      },
      loginMethod: AnalyticsLoginMethod.apple,
      providerName: 'Apple',
      pageName: AnalyticsPageName.loginSignIn,
    );
  }

  Future<OnboardingAuthResult?> _authorize({
    required Future<OnboardingAuthResult> Function() request,
    required AnalyticsLoginMethod loginMethod,
    required String providerName,
    required AnalyticsPageName pageName,
  }) async {
    if (state.isLoading) return null;
    state = const AuthEntryState(isLoading: true);
    try {
      final result = await request();
      ref.read(authSessionProvider.notifier).markAuthenticated(result.token);
      final analytics = ref.read(analyticsProvider);
      await analytics.identifyUser(
        AnalyticsUserIdentity(
          appUserId: result.userId.toString(),
          shopifyCustomerId: result.shopifyCustomerId?.toString(),
        ),
        loginMethod: loginMethod,
      );
      await _reportLoginResult(
        isSuccess: true,
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = const AuthEntryState();
      return result;
    } on FlutterAppAuthUserCancelledException {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'oauth_cancelled: User cancelled Shopify authorization',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = const AuthEntryState(errorMessage: 'Shopify login was cancelled');
      return null;
    } on SignInWithAppleAuthorizationException catch (error) {
      final isCancelled = error.code == AuthorizationErrorCode.canceled;
      await _reportLoginResult(
        isSuccess: false,
        failReason: isCancelled
            ? 'oauth_cancelled: User cancelled Apple authorization'
            : 'oauth_error: ${error.message}',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = AuthEntryState(
        errorMessage: isCancelled
            ? 'Apple login was cancelled'
            : 'Unable to log in with Apple',
      );
      return null;
    } on AppleIdentityTokenMissingException {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'identity_token_missing: Apple returned no identity token',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = const AuthEntryState(
        errorMessage: 'Apple did not return an identity token',
      );
      return null;
    } on ApiException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: '${error.code}: ${error.message}',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on SessionExpiredException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'session_expired: ${error.message}',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on NetworkException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: '${error.type.name}: ${error.message}',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on ResponseFormatException catch (error) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'response_format_error: ${error.message}',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = AuthEntryState(errorMessage: error.message);
      return null;
    } on FlutterAppAuthPlatformException catch (error) {
      final message = error.message ?? 'Unable to log in with $providerName';
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'oauth_error: $message',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = AuthEntryState(errorMessage: message);
      return null;
    } catch (_) {
      await _reportLoginResult(
        isSuccess: false,
        failReason: 'unknown_error: Unable to log in with $providerName',
        loginMethod: loginMethod,
        pageName: pageName,
      );
      state = AuthEntryState(
        errorMessage: 'Unable to log in with $providerName',
      );
      return null;
    } finally {
      if (state.isLoading) state = const AuthEntryState();
    }
  }

  Future<void> _reportLoginResult({
    required bool isSuccess,
    required AnalyticsLoginMethod loginMethod,
    required AnalyticsPageName pageName,
    String failReason = '',
  }) {
    return ref
        .read(analyticsProvider)
        .report(
          AnalyticsEvent.loginRequestResult,
          properties: {
            AnalyticsEventProperty.pageName: pageName.value,
            AnalyticsEventProperty.loginMethod: loginMethod.value,
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
