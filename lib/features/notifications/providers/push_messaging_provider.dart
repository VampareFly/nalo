// 管理 Firebase Messaging 客户端生命周期，并在有效登录状态下同步 FCM Token。
// 身份解绑与业务 Push 触发均由服务端负责，本 Provider 只处理客户端注册和消息消费。

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/app/navigation/common_jump_handler.dart';
import 'package:nalo/app/navigation/initial_page_ready_provider.dart';
import 'package:nalo/core/analytics/analytics.dart';
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
  PushRemoteMessage? _pendingInitialMessage;
  final Set<String> _reportedReceivedPushes = {};

  @override
  void build() {
    if (!_isSupportedPlatform) return;

    final service = ref.watch(pushMessagingServiceProvider);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(_configureForegroundPresentation(service));
    }
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
    ref.listen<bool>(initialPageReadyProvider, (_, isReady) {
      if (isReady) _tryConsumePendingInitialMessage();
    });
    unawaited(_handleInitialMessage());
  }

  Future<void> _configureForegroundPresentation(
    PushMessagingService service,
  ) async {
    try {
      await service.configureForegroundPresentation();
    } catch (error, stackTrace) {
      ref
          .read(loggerProvider)
          .e(
            'Foreground push presentation configuration failed.',
            error: error,
            stackTrace: stackTrace,
          );
    }
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
      if (next.hasValue) _tryConsumePendingInitialMessage();
      return;
    }
    _tryConsumePendingInitialMessage();
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
    _logPushMessage(message, source: 'foreground');
    _reportPushReceived(message);
  }

  void _handleMessageOpenedApp(PushRemoteMessage message) {
    _logPushMessage(message, source: 'background tap');
    _reportPushReceived(message);
    _reportPushClicked(message);
    _navigateFromPush(message);
  }

  Future<void> _handleInitialMessage() async {
    try {
      final message = await ref
          .read(pushMessagingServiceProvider)
          .getInitialMessage();
      if (message == null) return;
      _logPushMessage(message, source: 'terminated tap');
      _reportPushReceived(message);
      _reportPushClicked(message);
      _pendingInitialMessage = message;
      _tryConsumePendingInitialMessage();
    } catch (error, stackTrace) {
      _logTokenError(
        'Initial push message handling failed.',
        error,
        stackTrace,
      );
    }
  }

  void _tryConsumePendingInitialMessage() {
    final message = _pendingInitialMessage;
    if (message == null || !ref.read(initialPageReadyProvider)) return;

    final session = ref.read(authSessionProvider);
    if (session.isLoading) return;
    if (session.value?.status != AuthSessionStatus.authenticated) {
      _pendingInitialMessage = null;
      ref
          .read(loggerProvider)
          .d(
            'Initial push navigation ignored because session restoration '
            'did not authenticate the user.',
          );
      return;
    }

    _pendingInitialMessage = null;
    _navigateFromPush(message);
  }

  void _reportPushReceived(PushRemoteMessage message) {
    final deduplicationKey = _pushValue(message, 'push_id').isNotEmpty
        ? _pushValue(message, 'push_id')
        : message.messageId ?? '';
    if (deduplicationKey.isNotEmpty &&
        !_reportedReceivedPushes.add(deduplicationKey)) {
      return;
    }
    unawaited(
      ref
          .read(analyticsProvider)
          .report(
            AnalyticsEvent.pushReceive,
            properties: _pushAnalyticsProperties(message),
          ),
    );
  }

  void _reportPushClicked(PushRemoteMessage message) {
    unawaited(
      ref
          .read(analyticsProvider)
          .report(
            AnalyticsEvent.pushClick,
            properties: _pushAnalyticsProperties(message),
          ),
    );
  }

  Map<AnalyticsEventProperty, Object> _pushAnalyticsProperties(
    PushRemoteMessage message,
  ) {
    return {
      AnalyticsEventProperty.pushId: _pushValue(message, 'push_id'),
      AnalyticsEventProperty.pushType: _pushValue(
        message,
        'push_type',
        fallbackKey: 'type',
      ),
      AnalyticsEventProperty.title:
          message.notificationTitle ?? _pushValue(message, 'title'),
      AnalyticsEventProperty.content:
          message.notificationBody ??
          _pushValue(message, 'content', fallbackKey: 'body'),
    };
  }

  String _pushValue(
    PushRemoteMessage message,
    String key, {
    String? fallbackKey,
  }) {
    final value =
        message.data[key] ??
        (fallbackKey == null ? null : message.data[fallbackKey]);
    return value?.toString().trim() ?? '';
  }

  void _navigateFromPush(PushRemoteMessage message) {
    final target = message.data['target'];
    if (target is! String || target.trim().isEmpty) {
      ref
          .read(loggerProvider)
          .w('Push navigation ignored because target is missing.');
      return;
    }

    final action = message.data['action'];
    if (action != null && action is! String) {
      ref
          .read(loggerProvider)
          .w('Push navigation ignored because action is invalid.');
      return;
    }

    ref
        .read(commonJumpHandlerProvider)
        .navigate(
          target: target.trim(),
          action: action as String? ?? '',
          source: AnalyticsTestFlowSource.push,
        );
  }

  void _logPushMessage(
    PushRemoteMessage message, {
    required String source,
  }) {
    if (!kDebugMode) return;
    ref.read(loggerProvider).d(
      'Push message received\n'
      'source: $source\n'
      'messageId: ${message.messageId ?? 'null'}\n'
      'notification: {'
      'title: ${message.notificationTitle ?? 'null'}, '
      'body: ${message.notificationBody ?? 'null'}'
      '}\n'
      'data: ${message.data}',
    );
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
