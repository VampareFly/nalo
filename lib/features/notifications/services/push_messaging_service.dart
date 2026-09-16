// 封装 Firebase Messaging 客户端能力，负责 FCM Token 与远程消息事件转换。
// Provider 在登录状态变化时调用 Token 接口，并消费前台及通知点击事件。

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// 客户端关心的远程消息最小模型；业务 Payload 协议确认后在此集中扩展。
class PushRemoteMessage {
  const PushRemoteMessage({required this.messageId, required this.data});

  final String? messageId;
  final Map<String, dynamic> data;

  /// 从 Firebase 消息转换为业务无关的客户端消息。
  factory PushRemoteMessage.fromFirebase(RemoteMessage message) {
    return PushRemoteMessage(messageId: message.messageId, data: message.data);
  }
}

/// 提供 FCM Token、前台消息和通知点击事件。
abstract interface class PushMessagingService {
  Stream<String> get onTokenRefresh;

  Stream<PushRemoteMessage> get onForegroundMessage;

  Stream<PushRemoteMessage> get onMessageOpenedApp;

  /// 获取当前 App 实例的 FCM Token；iOS 尚未取得 APNs Token 时返回空。
  Future<String?> getToken();

  /// 获取通过通知启动 App 时携带的初始消息。
  Future<PushRemoteMessage?> getInitialMessage();
}

/// 使用 Firebase Messaging 实现远程推送客户端能力。
class FirebasePushMessagingService implements PushMessagingService {
  const FirebasePushMessagingService(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushRemoteMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(PushRemoteMessage.fromFirebase);

  @override
  Stream<PushRemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(
        PushRemoteMessage.fromFirebase,
      );

  @override
  Future<String?> getToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _messaging.getAPNSToken() == null) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Future<PushRemoteMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushRemoteMessage.fromFirebase(message);
  }
}
