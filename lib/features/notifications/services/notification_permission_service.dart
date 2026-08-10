import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class NotificationPermissionService {
  Future<bool> isNotificationPermissionEnabled();

  Future<bool> requestNotificationPermission();

  Future<bool> openAppSettings();
}

class PlatformNotificationPermissionService implements NotificationPermissionService {
  static const _channel = MethodChannel('com.sanjiang.nala/notification_permission');

  @override
  Future<bool> isNotificationPermissionEnabled() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    return await _channel.invokeMethod<bool>('isNotificationPermissionEnabled') ?? false;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    return await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;
  }

  @override
  Future<bool> openAppSettings() async {
    if (!_isSupportedPlatform) {
      return false;
    }

    return await _channel.invokeMethod<bool>('openAppSettings') ?? false;
  }

  bool get _isSupportedPlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
}
