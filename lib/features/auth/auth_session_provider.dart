// 管理应用级认证会话、冷启动 Token 恢复和分析身份清理。
// Token 失效、主动退出或账号注销后清理业务会话并重置 Amplitude 身份。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/network/api_client.dart';
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
      try {
        final refreshedToken = await repository.refresh(token);
        return AuthSessionState(
          status: AuthSessionStatus.authenticated,
          token: refreshedToken,
        );
      } on SessionExpiredException catch (error) {
        await repository.clearSession();
        await ref.read(analyticsProvider).resetIdentity();
        return AuthSessionState(
          status: AuthSessionStatus.sessionExpired,
          expirationMessage: error.message,
        );
      } catch (_) {
        return AuthSessionState(
          status: AuthSessionStatus.authenticated,
          token: token,
        );
      }
    }

    return AuthSessionState(
      status: AuthSessionStatus.authenticated,
      token: token,
    );
  }

  /// 登录成功后同步内存会话状态。
  void markAuthenticated(AuthToken token) {
    state = AsyncData(
      AuthSessionState(status: AuthSessionStatus.authenticated, token: token),
    );
  }

  /// 服务端判定 Token 过期后统一切换为未登录会话。
  Future<void> markExpired(String message) async {
    final currentStatus = state.value?.status;
    if (currentStatus == AuthSessionStatus.sessionExpired ||
        currentStatus == AuthSessionStatus.unauthenticated) {
      return;
    }
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

  /// 主动退出并清理本地认证数据及 Amplitude 身份。
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

  /// 注销成功后清理该用户 Welcome 状态并结束当前会话。
  Future<void> deactivate() async {
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
    try {
      await ref.read(analyticsProvider).resetIdentity();
    } finally {
      state = const AsyncData(
        AuthSessionState(status: AuthSessionStatus.unauthenticated),
      );
    }
  }
}
