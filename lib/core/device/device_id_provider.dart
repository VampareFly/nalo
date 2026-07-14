import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/core/device/device_id_service.dart';

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return PlatformDeviceIdService();
});
