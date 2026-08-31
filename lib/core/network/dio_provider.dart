// 配置项目 Dio 的抓包代理与临时证书策略。
// 抓包默认开启；Google Play 等正式分发构建通过 dart-define 显式关闭。

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 是否允许当前构建使用系统代理并接受抓包代理证书。
///
/// 默认允许；正式分发时使用 `ALLOW_NETWORK_INSPECTION=false` 显式关闭。
const networkInspectionEnabled = bool.fromEnvironment(
  'ALLOW_NETWORK_INSPECTION',
  defaultValue: true,
);

/// Android 系统代理地址，用于允许抓包的构建。
class SystemProxy {
  const SystemProxy({required this.host, required this.port});

  final String host;
  final int port;

  String get dartProxyConfiguration => 'PROXY $host:$port';
}

SystemProxy? _debugSystemProxy;

/// 在允许抓包的 Android 构建启动阶段读取当前 Wi-Fi/系统代理。
///
/// 未配置代理或平台通道不可用时保持直连，避免抓包能力影响 App 启动。
Future<void> initializeDebugSystemProxy() async {
  if (!networkInspectionEnabled || !Platform.isAndroid) return;

  try {
    const channel = MethodChannel('com.sanjiang.nalo/system_proxy');
    final proxy = await channel.invokeMapMethod<String, Object?>(
      'getSystemProxy',
    );
    final host = proxy?['host'];
    final port = proxy?['port'];
    if (host is String && host.isNotEmpty && port is int && port > 0) {
      _debugSystemProxy = SystemProxy(host: host, port: port);
    }
  } on PlatformException {
    _debugSystemProxy = null;
  } on MissingPluginException {
    _debugSystemProxy = null;
  }
}

/// 临时允许 Dio 接受抓包代理生成的 HTTPS 证书。
///
/// 默认方便本地包和联调包抓包；正式分发构建关闭开关后保留系统默认 TLS 校验。
/// Android 允许抓包的构建会同时应用启动阶段读取到的系统代理。
void configureCertificateBypass(Dio dio) {
  if (!networkInspectionEnabled) return;

  final adapter = IOHttpClientAdapter();
  adapter.createHttpClient = () {
    final client = HttpClient();
    final proxy = _debugSystemProxy;
    if (proxy != null) {
      client.findProxy = (_) => proxy.dartProxyConfiguration;
    }
    // 抓包代理会动态签发目标站点证书；当前联调阶段临时接受该证书。
    // 正式分发必须关闭抓包开关，否则 App 会接受任意不可信证书。
    client.badCertificateCallback = (certificate, host, port) => true;
    return client;
  };
  dio.httpClientAdapter = adapter;
}

/// 创建并管理项目统一的 Dio 客户端。
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
  configureCertificateBypass(dio);

  ref.onDispose(dio.close);
  return dio;
});
