import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 获取应用使用的设备 ID。
abstract interface class DeviceIdService {
  /// 返回由原生平台保存的设备 ID。
  Future<String> getDeviceId();
}

/// 通过 MethodChannel 从 iOS 或 Android 获取设备 ID。
class PlatformDeviceIdService implements DeviceIdService {
  static const _channel = MethodChannel('com.sanjiang.nala/device_id');

  @override
  /// 获取设备 ID；当前仅支持 iOS 和 Android。
  Future<String> getDeviceId() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Device ID is currently only supported on iOS and Android.');
    }

    final deviceId = await _channel.invokeMethod<String>('getDeviceId');
    if (deviceId == null || deviceId.isEmpty) {
      throw StateError('The platform returned an invalid device ID.');
    }
    return deviceId;
  }
}
