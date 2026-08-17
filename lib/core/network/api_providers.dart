// 组装自有业务 API 的 Dio、公共 Header 和应用级会话过期事件。
// 每次请求动态读取 Token、应用、设备及系统信息；Shopify OAuth 不经过本文件。

import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nalo/app/config/app_environment.dart';
import 'package:nalo/app/config/app_version_provider.dart';
import 'package:nalo/core/device/device_id_provider.dart';
import 'package:nalo/core/device/device_id_service.dart';
import 'package:nalo/core/logging/logger_provider.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/auth/token_storage.dart';

/// 一次请求需要注入的应用和设备信息。
class RequestContext {
  const RequestContext({
    required this.appVersion,
    required this.appBuild,
    required this.platform,
    required this.deviceId,
    required this.requestId,
    required this.language,
    required this.timezone,
  });

  /// `X-App-Version`：来自 `PackageInfo.version`，对应 pubspec 中版本号的 `x.y.z` 部分。
  final String appVersion;

  /// `X-App-Build`：来自 `PackageInfo.buildNumber`，对应 pubspec 中版本号的 `+build` 部分。
  final String appBuild;

  /// `X-Platform`：来自 Flutter 当前运行平台，iOS/Android 分别传 `ios`/`android`。
  final String platform;

  /// `X-Device-ID`：由 `DeviceIdService` 读取或首次生成的本地设备标识。
  final String deviceId;

  /// `X-Request-ID`：客户端为每次请求独立生成的 UUID v4，用于日志链路追踪。
  final String requestId;

  /// `X-Language`：来自系统 Locale，格式为 `languageCode-countryCode`，如 `zh-CN`。
  final String language;

  /// `X-Timezone`：来自系统时区标识，如 `Asia/Shanghai`。
  final String timezone;
}

/// 按请求加载公共 Header 所需的动态信息。
class RequestContextLoader {
  RequestContextLoader({
    required this._packageInfo,
    required this._deviceIdService,
    Random? random,
  }) : _random = random ?? Random.secure();

  final PackageInfo _packageInfo;
  final DeviceIdService _deviceIdService;
  final Random _random;

  /// 创建当前请求的公共上下文。
  Future<RequestContext> load() async {
    final locale = PlatformDispatcher.instance.locale;
    final timezone = await FlutterTimezone.getLocalTimezone();
    return RequestContext(
      appVersion: _packageInfo.version,
      appBuild: _packageInfo.buildNumber,
      platform: switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => defaultTargetPlatform.name,
      },
      deviceId: await _deviceIdService.getDeviceId(),
      requestId: _uuidV4(),
      language: _languageTag(locale),
      timezone: timezone.identifier,
    );
  }

  String _languageTag(Locale locale) {
    final countryCode = locale.countryCode;
    return countryCode == null || countryCode.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}-$countryCode';
  }

  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

/// 为自有业务 API 请求动态注入公共 Header。
class RequestContextInterceptor extends Interceptor {
  RequestContextInterceptor({
    required this._contextLoader,
    required this._tokenStorage,
  });

  final RequestContextLoader _contextLoader;
  final TokenStorage _tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final context = await _contextLoader.load();
      // 将 RequestContext 中注明的应用、设备和系统信息映射为服务端约定的 Header。
      options.headers.addAll({
        'X-App-Version': context.appVersion,
        'X-App-Build': context.appBuild,
        'X-Platform': context.platform,
        'X-Device-ID': context.deviceId,
        'X-Request-ID': context.requestId,
        'X-Language': context.language,
        'X-Timezone': context.timezone,
      });
      // 除显式标记 requiresAuth=false 的公开接口外，从 TokenStorage 读取 Access Token。
      if (options.extra['requiresAuth'] != false) {
        final token = await _tokenStorage.read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer ${token.accessToken}';
        }
      }
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}

/// 广播服务端判定 Access Token 过期的全局事件。
class SessionExpirationNotifier {
  final _controller = StreamController<String>.broadcast();

  /// 会话过期事件流，供应用根部统一处理。
  Stream<String> get stream => _controller.stream;

  /// 通知一次会话过期事件。
  void notify(String message) => _controller.add(message);

  /// 释放事件流资源。
  Future<void> dispose() => _controller.close();
}

/// 广播业务响应中的会话过期事件。
final sessionExpirationNotifierProvider = Provider<SessionExpirationNotifier>((
  ref,
) {
  final notifier = SessionExpirationNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// 将会话过期事件转换为 Riverpod 异步流。
final sessionExpirationStreamProvider = StreamProvider<String>((ref) {
  return ref.watch(sessionExpirationNotifierProvider).stream;
});

/// 创建自有业务后端专用的 ApiClient。
final businessApiClientProvider = FutureProvider<ApiClient>((ref) async {
  final tokenStorage = await ref.watch(tokenStorageProvider.future);
  final packageInfo = await ref.watch(appPackageInfoProvider.future);
  final expirationNotifier = ref.watch(sessionExpirationNotifierProvider);
  final dio = Dio(
    BaseOptions(
      // Host 由该 baseUrl 自动生成；User-Agent 由 Dart HTTP 底层自动生成。
      baseUrl: currentEnvironment.apiBaseUrl,
      // 统一将 Content-Type 设为 application/json。
      contentType: Headers.jsonContentType,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  dio.interceptors.addAll([
    RequestContextInterceptor(
      contextLoader: RequestContextLoader(
        packageInfo: packageInfo,
        deviceIdService: ref.watch(deviceIdServiceProvider),
      ),
      tokenStorage: tokenStorage,
    ),
    NetworkLogInterceptor(ref.watch(loggerProvider)),
  ]);
  ref.onDispose(dio.close);
  return ApiClient(
    dio: dio,
    onSessionExpired: (message) async {
      await tokenStorage.clear();
      expirationNotifier.notify(message);
    },
  );
});
