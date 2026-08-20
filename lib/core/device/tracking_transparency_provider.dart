// 注入 ATT/IDFA 平台能力，业务层不直接依赖 MethodChannel。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/device/tracking_transparency_service.dart';

/// 注入 iOS ATT 和 IDFA 平台服务。
final trackingTransparencyServiceProvider =
    Provider<TrackingTransparencyService>((ref) {
      return PlatformTrackingTransparencyService();
    });
