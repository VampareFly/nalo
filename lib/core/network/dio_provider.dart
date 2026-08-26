import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 临时允许 Dio 接受抓包代理生成的 HTTPS 证书。
///
/// 当前所有构建模式都会调用，方便联调包和本地包抓包；正式上线前必须按照
/// `RELEASE_CHECKLIST.md` 删除该配置并恢复系统默认 TLS 校验。
/// 本方法只放宽证书校验，不负责设置 Charles、Proxyman 等工具的代理地址。
void configureCertificateBypass(Dio dio) {
  final adapter = IOHttpClientAdapter();
  adapter.createHttpClient = () {
    final client = HttpClient();
    // 抓包代理会动态签发目标站点证书；当前联调阶段临时接受该证书。
    // 上线前必须删除此回调，否则正式包会接受任意不可信证书。
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
