// 管理应用级认证会话、分析平台身份恢复和后台静默刷新。
// 有效 Session 先恢复分析身份与页面流程，刷新结果仅在会话未变化时写回。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/auth/auth_repository.dart';
import 'package:nalo/features/auth/auth_token.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/onboarding/repositories/welcome_completion_repository.dart';

/// 应用认证会话所处阶段。
enum AuthSessionStatus { authenticated, unauthenticated, sessionExpired }

/// 应用级认证会话状态。
class AuthSessionState {
  const AuthSessionState({
    required this.status,
    this.token,
    this.expirationMessage,
  });

  final AuthSessionStatus status;
  final AuthToken? token;
  final String? expirationMessage;
}

/// 提供冷启动恢复和会话清理能力。
final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSessionState>(
      AuthSessionNotifier.new,
    );

/// 编排认证会话生命周期。
class AuthSessionNotifier extends AsyncNotifier<AuthSessionState> {
  static const _refreshThreshold = Duration(days: 1);

  @override
  Future<AuthSessionState> build() => _restoreSession();

  Future<AuthSessionState> _restoreSession() async {
    final repository = await ref.watch(authRepositoryProvider.future);
    final token = await repository.readToken();
    if (token == null) {
      return const AuthSessionState(status: AuthSessionStatus.unauthenticated);
    }

    final now = DateTime.now().toUtc();
    final expiresAt = token.expiresAt.toUtc();
    if (!expiresAt.isAfter(now)) {
      await repository.clearSession();
      await ref.read(analyticsProvider).resetIdentity();
      return const AuthSessionState(
        status: AuthSessionStatus.sessionExpired,
        expirationMessage: 'Your login has expired. Please log in again.',
      );
    }

    if (expiresAt.difference(now) < _refreshThreshold) {
      unawaited(_refreshInBackground(repository, token));
    }

    await _restoreAnalyticsIdentity();

    return AuthSessionState(
      status: AuthSessionStatus.authenticated,
      token: token,
    );
  }

  /// 从本地用户快照恢复 Amplitude 与 GA4 各自使用的用户身份。
  Future<void> _restoreAnalyticsIdentity() async {
    try {
      final userStorage = await ref.read(currentUserStorageProvider.future);
      final currentUser = await userStorage.read();
      if (currentUser == null) return;
      await ref
          .read(analyticsProvider)
          .restoreUserIdentity(
            AnalyticsUserIdentity(
              appUserId: currentUser.id.toString(),
              shopifyCustomerId: currentUser.shopifyCustomerId?.toString(),
            ),
          );
    } catch (_) {
      // 分析身份恢复属于可降级能力，不阻塞有效 Session 进入应用。
    }
  }

  /// 后台静默刷新临近过期的 Token，任何失败都不影响当前有效 Session。
  Future<void> _refreshInBackground(
    AuthRepository repository,
    AuthToken currentToken,
  ) async {
    try {
      final refreshedToken = await repository.refresh(currentToken);
      if (refreshedToken == null) return;
      final currentSession = state.value;
      if (currentSession?.status != AuthSessionStatus.authenticated ||
          currentSession?.token != currentToken) {
        return;
      }
      state = AsyncData(
        AuthSessionState(
          status: AuthSessionStatus.authenticated,
          token: refreshedToken,
        ),
      );
    } catch (_) {
      // Refresh 是可降级能力，旧 Access Token 有效时不阻塞用户或展示错误。
    }
  }

  /// 登录成功后同步内存会话状态。
  void markAuthenticated(AuthToken token) {
    state = AsyncData(
      AuthSessionState(status: AuthSessionStatus.authenticated, token: token),
    );
  }

  /// 每次收到登录失效响应都幂等清理会话，并重新发布失效状态供全局弹窗消费。
  Future<void> markExpired(String message) async {
    final repository = await ref.read(authRepositoryProvider.future);
    await repository.clearSession();
    await ref.read(analyticsProvider).resetIdentity();
    state = AsyncData(
      AuthSessionState(
        status: AuthSessionStatus.sessionExpired,
        expirationMessage: message,
      ),
    );
  }

  /// 主动退出并清理本地认证数据及所有分析平台身份。
  Future<void> logout() async {
    final repository = await ref.read(authRepositoryProvider.future);
    try {
      await repository.logout();
    } catch (_) {
      // 用户已明确退出，服务端失败不应阻止本地会话结束。
    } finally {
      await ref.read(analyticsProvider).resetIdentity();
      state = const AsyncData(
        AuthSessionState(status: AuthSessionStatus.unauthenticated),
      );
    }
  }

  /// 注销成功后清理 Welcome 状态，并在身份重置前执行可选回调。
  Future<void> deactivate({
    Future<void> Function()? beforeIdentityReset,
  }) async {
    final userStorage = await ref.read(currentUserStorageProvider.future);
    final currentUser = await userStorage.read();
    final repository = await ref.read(authRepositoryProvider.future);
    await repository.deactivate();
    if (currentUser != null) {
      try {
        final welcomeRepository = await ref.read(
          welcomeCompletionRepositoryProvider.future,
        );
        await welcomeRepository.clear(currentUser.id);
      } catch (_) {
        // TODO: <pf> 增加本地用户状态清理失败的统一重试机制。
      }
    }
    await beforeIdentityReset?.call();
    try {
      await ref.read(analyticsProvider).resetIdentity();
    } finally {
      state = const AsyncData(
        AuthSessionState(status: AuthSessionStatus.unauthenticated),
      );
    }
  }
}
