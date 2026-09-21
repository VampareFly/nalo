// 管理 Firebase Messaging 客户端生命周期，并在有效登录状态下同步 FCM Token。
// 身份解绑与业务 Push 触发均由服务端负责，本 Provider 只处理客户端注册和消息消费。

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/logging/logger_provider.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/notifications/repositories/push_token_repository.dart';
import 'package:nalo/features/notifications/services/push_messaging_service.dart';

/// 注入 Firebase Messaging 客户端 Service。
final pushMessagingServiceProvider = Provider<PushMessagingService>((ref) {
  return FirebasePushMessagingService(FirebaseMessaging.instance);
});

/// 协调登录状态、FCM Token 同步及远程消息事件。
class PushMessagingNotifier extends Notifier<void> {
  String? _lastUploadedToken;

  @override
  void build() {
    if (!_isSupportedPlatform) return;

    final service = ref.watch(pushMessagingServiceProvider);
    final tokenSubscription = service.onTokenRefresh.listen(
      _handleTokenRefresh,
      onError: (Object error, StackTrace stackTrace) {
        ref
            .read(loggerProvider)
            .e(
              'FCM token refresh failed.',
              error: error,
              stackTrace: stackTrace,
            );
      },
    );
    final foregroundSubscription = service.onForegroundMessage.listen(
      _handleForegroundMessage,
      onError: _logMessageStreamError,
    );
    final openedSubscription = service.onMessageOpenedApp.listen(
      _handleMessageOpenedApp,
      onError: _logMessageStreamError,
    );

    ref.onDispose(() {
      unawaited(tokenSubscription.cancel());
      unawaited(foregroundSubscription.cancel());
      unawaited(openedSubscription.cancel());
    });
    ref.listen<AsyncValue<AuthSessionState>>(
      authSessionProvider,
      _handleAuthSessionChange,
      fireImmediately: true,
    );
    unawaited(_handleInitialMessage());
  }

  /// 登录成功、冷启动恢复登录态或认证凭证变化后同步当前 FCM Token。
  void _handleAuthSessionChange(
    AsyncValue<AuthSessionState>? previous,
    AsyncValue<AuthSessionState> next,
  ) {
    final previousSession = previous?.value;
    final nextSession = next.value;
    if (nextSession?.status != AuthSessionStatus.authenticated) {
      _lastUploadedToken = null;
      return;
    }
    final becameAuthenticated =
        previousSession?.status != AuthSessionStatus.authenticated;
    final credentialsChanged = previousSession?.token != nextSession?.token;
    if (becameAuthenticated || credentialsChanged) {
      unawaited(_loadAndUploadToken());
    }
  }

  Future<void> _loadAndUploadToken() async {
    try {
      final token = await ref.read(pushMessagingServiceProvider).getToken();
      if (token == null || token.isEmpty) return;
      _logDebugToken(token, source: 'initial');
      await _uploadTokenWhenAuthenticated(token);
    } catch (error, stackTrace) {
      _logTokenError('FCM token acquisition failed.', error, stackTrace);
    }
  }

  void _handleTokenRefresh(String token) {
    _logDebugToken(token, source: 'refresh');
    // 刷新事件可能发生在任意页面，仅登录态有效时重新绑定当前用户。
    unawaited(_uploadTokenWhenAuthenticated(token));
  }

  void _logDebugToken(String token, {required String source}) {
    if (!kDebugMode) return;
    ref.read(loggerProvider).d('FCM token ($source): $token');
  }

  Future<void> _uploadTokenWhenAuthenticated(String token) async {
    if (token.isEmpty || token == _lastUploadedToken) return;
    final session = ref.read(authSessionProvider).value;
    if (session?.status != AuthSessionStatus.authenticated) return;

    try {
      final repository = await ref.read(pushTokenRepositoryProvider.future);
      if (ref.read(authSessionProvider).value?.status !=
          AuthSessionStatus.authenticated) {
        return;
      }
      await repository.registerToken(token);
      _lastUploadedToken = token;
    } catch (error, stackTrace) {
      _logTokenError('FCM token upload failed.', error, stackTrace);
    }
  }

  void _handleForegroundMessage(PushRemoteMessage message) {
    ref
        .read(loggerProvider)
        .d(
          'Foreground push received. messageId=${message.messageId ?? 'none'}',
        );
    // TODO: <pf> 服务端确认 Push Payload 和前台 UI 后，在此分发前台消息。
  }

  void _handleMessageOpenedApp(PushRemoteMessage message) {
    ref
        .read(loggerProvider)
        .d(
          'Push opened from background. messageId=${message.messageId ?? 'none'}',
        );
    // TODO: <pf> 服务端确认 Payload 与页面映射后，通过统一跳转处理器传入 source=push。
  }

  Future<void> _handleInitialMessage() async {
    try {
      final message = await ref
          .read(pushMessagingServiceProvider)
          .getInitialMessage();
      if (message == null) return;
      ref
          .read(loggerProvider)
          .d(
            'Push opened from terminated state. '
            'messageId=${message.messageId ?? 'none'}',
          );
      // TODO: <pf> 服务端确认 Payload 与页面映射后，通过统一跳转处理器传入 source=push。
    } catch (error, stackTrace) {
      _logTokenError(
        'Initial push message handling failed.',
        error,
        stackTrace,
      );
    }
  }

  void _logMessageStreamError(Object error, StackTrace stackTrace) {
    ref
        .read(loggerProvider)
        .e('Push message stream failed.', error: error, stackTrace: stackTrace);
  }

  void _logTokenError(String message, Object error, StackTrace stackTrace) {
    ref.read(loggerProvider).e(message, error: error, stackTrace: stackTrace);
  }

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
}

/// 提供应用进程内共享的 Firebase Messaging 生命周期。
final pushMessagingProvider = NotifierProvider<PushMessagingNotifier, void>(
  PushMessagingNotifier.new,
);
