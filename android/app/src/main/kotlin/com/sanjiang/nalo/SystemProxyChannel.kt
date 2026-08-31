// 向 Flutter 暴露 Android 当前系统代理，供允许抓包的构建配置 Dio。
// App 启动时读取一次；未配置手动代理时返回 null，由网络层保持直连。
package com.sanjiang.nalo

import android.content.Context
import android.net.ConnectivityManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** 读取 Android 当前网络使用的系统代理。 */
object SystemProxyChannel {
    private const val channelName = "com.sanjiang.nalo/system_proxy"
    private const val methodGetSystemProxy = "getSystemProxy"

    /** 注册系统代理查询通道，供 Flutter 在启动阶段调用。 */
    fun register(binaryMessenger: BinaryMessenger, context: Context) {
        val connectivityManager = context.getSystemService(ConnectivityManager::class.java)
        MethodChannel(binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method != methodGetSystemProxy) {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val proxy = connectivityManager.defaultProxy
            val host = proxy?.host
            val port = proxy?.port ?: -1
            if (host.isNullOrBlank() || port <= 0) {
                result.success(null)
                return@setMethodCallHandler
            }

            result.success(mapOf("host" to host, "port" to port))
        }
    }
}
