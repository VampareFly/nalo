// iOS ATT 与 IDFA 平台能力封装。
// iOS 返回真实或全 0 IDFA，Android 和其他平台不设置该用户属性。

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 请求跟踪授权并读取平台广告标识。
abstract interface class TrackingTransparencyService {
  /// iOS 返回 IDFA；非 iOS 返回 null。
  Future<String?> requestAdvertisingId();
}

/// 通过 MethodChannel 调用 iOS ATT 和 AdSupport。
class PlatformTrackingTransparencyService
    implements TrackingTransparencyService {
  static const _channel = MethodChannel(
    'com.sanjiang.nalo/tracking_transparency',
  );

  @override
  Future<String?> requestAdvertisingId() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    return _channel.invokeMethod<String>('requestAdvertisingId');
  }
}
