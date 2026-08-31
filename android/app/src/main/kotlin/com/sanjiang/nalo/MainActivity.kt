package com.sanjiang.nalo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var notificationPermissionChannel: NotificationPermissionChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceIdChannel.register(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            context = applicationContext,
        )
        SystemProxyChannel.register(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            context = applicationContext,
        )
        notificationPermissionChannel = NotificationPermissionChannel(this)
        notificationPermissionChannel.register(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "nalo/native_camera_view",
            NativeCameraViewFactory(
                messenger = flutterEngine.dartExecutor.binaryMessenger,
                lifecycleOwner = this,
            ),
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (
            ::notificationPermissionChannel.isInitialized &&
            notificationPermissionChannel.onRequestPermissionsResult(
                requestCode,
                permissions,
                grantResults,
            )
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
