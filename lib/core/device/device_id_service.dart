import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class DeviceIdService {
  Future<String> getDeviceId();
}

class PlatformDeviceIdService implements DeviceIdService {
  static const _channel = MethodChannel('com.sanjiang.testerkit/device_id');

  @override
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
