import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/core/device/device_id_service.dart';

/// 注入设备 ID 服务，业务层不直接访问平台通道。
final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return PlatformDeviceIdService();
});
