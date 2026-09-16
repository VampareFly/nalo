// 提供 Flutter 使用的 ATT 和 IDFA 能力。
// 用户未授权、拒绝或受限时统一返回系统全 0 IDFA。

import AdSupport
import AppTrackingTransparency
import Flutter

/// 统一注册 Flutter ATT 请求并返回可上报的 IDFA。
enum TrackingTransparencyChannel {
  private static let channelName = "com.rnbl.nalo/tracking_transparency"
  private static let unavailableAdvertisingId =
    "00000000-0000-0000-0000-000000000000"

  /// Flutter Engine 初始化后注册平台通道。
  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "requestAdvertisingId" else {
        result(FlutterMethodNotImplemented)
        return
      }
      requestAdvertisingId(result: result)
    }
  }

  private static func requestAdvertisingId(result: @escaping FlutterResult) {
    ATTrackingManager.requestTrackingAuthorization { status in
      let advertisingId = status == .authorized
        ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
        : unavailableAdvertisingId
      DispatchQueue.main.async {
        result(advertisingId)
      }
    }
  }
}
