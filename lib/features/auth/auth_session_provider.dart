// 管理应用级认证会话与冷启动 Token 恢复。
// 冷启动读取本地 Token：过期则清理，一天内到期则静默尝试刷新。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/auth/auth_repository.dart';
import 'package:tester_kit/features/auth/auth_token.dart';

/// 应用认证会话所处阶段。
enum AuthSessionStatus { authenticated, unauthenticated, sessionExpired }

/// 应用级认证会话状态。
class AuthSessionState {
  const AuthSessionState({required this.status, this.token});

  final AuthSessionStatus status;
  final AuthToken? token;
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
    if (!token.expiresAt.toUtc().isAfter(now)) {
      await repository.clearSession();
      return const AuthSessionState(status: AuthSessionStatus.sessionExpired);
    }

    if (token.expiresAt.toUtc().difference(now) <= _refreshThreshold) {
      try {
        final refreshedToken = await repository.refresh(token);
        return AuthSessionState(
          status: AuthSessionStatus.authenticated,
          token: refreshedToken,
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
  Future<void> markExpired() async {
    final currentStatus = state.value?.status;
    if (currentStatus == AuthSessionStatus.sessionExpired) return;
    final repository = await ref.read(authRepositoryProvider.future);
    await repository.clearSession();
    state = const AsyncData(
      AuthSessionState(status: AuthSessionStatus.sessionExpired),
    );
  }

  /// 主动退出并清理本地认证数据。
  Future<void> logout() async {
    final repository = await ref.read(authRepositoryProvider.future);
    await repository.clearSession();
    state = const AsyncData(
      AuthSessionState(status: AuthSessionStatus.unauthenticated),
    );
  }
}
