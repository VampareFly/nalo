import Flutter
import UIKit
import UserNotifications

enum NotificationChannel {
  private static let channelName = "com.sanjiang.nala/notification_permission"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isNotificationPermissionEnabled":
        isNotificationPermissionEnabled(result: result)
      case "requestNotificationPermission":
        requestNotificationPermission(result: result)
      case "openAppSettings":
        openAppSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func isNotificationPermissionEnabled(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let isEnabled: Bool
      switch settings.authorizationStatus {
      case .authorized, .provisional:
        isEnabled = true
      case .denied, .notDetermined:
        isEnabled = false
      @unknown default:
        if #available(iOS 14.0, *), settings.authorizationStatus == .ephemeral {
          isEnabled = true
        } else {
          isEnabled = false
        }
      }
      DispatchQueue.main.async {
        result(isEnabled)
      }
    }
  }

  private static func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { isGranted, error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "notification_permission_request_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }
        result(isGranted)
      }
    }
  }

  private static func openAppSettings(result: @escaping FlutterResult) {
    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(settingsUrl, options: [:]) { didOpen in
      result(didOpen)
    }
  }
}
