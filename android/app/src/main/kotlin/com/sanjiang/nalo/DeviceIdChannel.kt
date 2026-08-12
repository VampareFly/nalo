package com.sanjiang.nalo

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors

object DeviceIdChannel {
    private const val channelName = "com.sanjiang.nalo/device_id"
    private const val methodGetDeviceId = "getDeviceId"
    private const val preferencesName = "device_id"
    private const val deviceIdKey = "device_id"
    private const val unavailableAdvertisingId = "00000000-0000-0000-0000-000000000000"

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(binaryMessenger: BinaryMessenger, context: Context) {
        val applicationContext = context.applicationContext
        MethodChannel(binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method != methodGetDeviceId) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            executor.execute {
                try {
                    val deviceId = getAdvertisingId(applicationContext) ?: getOrCreateLocalDeviceId(
                        applicationContext,
                    )
                    mainHandler.post { result.success(deviceId) }
                } catch (error: Exception) {
                    mainHandler.post {
                        result.error(
                            "device_id_storage_failed",
                            error.localizedMessage,
                            null,
                        )
                    }
                }
            }
        }
    }

    private fun getAdvertisingId(context: Context): String? {
        return try {
            val info = AdvertisingIdClient.getAdvertisingIdInfo(context)
            val advertisingId = info.id
            if (
                info.isLimitAdTrackingEnabled ||
                advertisingId.isNullOrBlank() ||
                advertisingId == unavailableAdvertisingId
            ) {
                null
            } else {
                advertisingId
            }
        } catch (_: Exception) {
            null
        }
    }

    @Synchronized
    private fun getOrCreateLocalDeviceId(context: Context): String {
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val storedDeviceId = preferences.getString(deviceIdKey, null)
        if (!storedDeviceId.isNullOrBlank()) {
            return storedDeviceId
        }

        val deviceId = UUID.randomUUID().toString()
        preferences.edit().putString(deviceIdKey, deviceId).apply()
        return deviceId
    }
}
