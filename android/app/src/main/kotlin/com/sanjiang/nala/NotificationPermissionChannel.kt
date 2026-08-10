package com.sanjiang.nala

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class NotificationPermissionChannel(private val activity: MainActivity) {
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun register(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                methodIsPermissionEnabled -> result.success(isNotificationPermissionEnabled())
                methodRequestPermission -> requestNotificationPermission(result)
                methodOpenAppSettings -> result.success(openAppSettings())
                else -> result.notImplemented()
            }
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != notificationPermissionRequestCode) {
            return false
        }

        val result = pendingPermissionResult
        pendingPermissionResult = null
        val permissionIndex = permissions.indexOf(Manifest.permission.POST_NOTIFICATIONS)
        val isGranted = permissionIndex >= 0 &&
            grantResults.getOrNull(permissionIndex) == PackageManager.PERMISSION_GRANTED
        result?.success(isGranted && areAppNotificationsEnabled())
        return true
    }

    private fun isNotificationPermissionEnabled(): Boolean {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return areAppNotificationsEnabled()
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(areAppNotificationsEnabled())
            return
        }
        if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(areAppNotificationsEnabled())
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "notification_permission_request_in_progress",
                "A notification permission request is already in progress.",
                null,
            )
            return
        }

        pendingPermissionResult = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode,
        )
    }

    private fun areAppNotificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return true
        }
        val notificationManager = activity.getSystemService(NotificationManager::class.java)
        return notificationManager.areNotificationsEnabled()
    }

    private fun openAppSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            }
        } else {
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${activity.packageName}"),
            )
        }

        return try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        const val channelName = "com.sanjiang.nala/notification_permission"
        const val methodIsPermissionEnabled = "isNotificationPermissionEnabled"
        const val methodRequestPermission = "requestNotificationPermission"
        const val methodOpenAppSettings = "openAppSettings"
        const val notificationPermissionRequestCode = 1001
    }
}
