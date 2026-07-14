import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        // TODO: <pf>
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
    }
}
