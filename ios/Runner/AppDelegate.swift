// iOS 应用入口，负责 Flutter 插件注册及 Firebase Messaging 的系统通知代理初始化。
import Flutter
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // UIScene 会晚于该回调注册 Flutter 插件，通知代理必须在启动回调返回前配置。
        FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        // flutter调用原生
        NotificationChannel.register(
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        DeviceIdChannel.register(
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        TrackingTransparencyChannel.register(
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeCameraPlugin") {
            NativeCameraPlugin.register(with: registrar)
        }
    }
}
