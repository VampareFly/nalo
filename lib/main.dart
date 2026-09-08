// 应用启动入口，依次完成系统 UI、基础服务与全局 Provider 初始化。
import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/constants.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nalo/app/app.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/analytics/amplitude_config.dart';
import 'package:nalo/core/crash_reporting/crash_reporting_service.dart';
import 'package:nalo/core/network/dio_provider.dart';
import 'package:nalo/core/network/provider_retry_policy.dart';

Future<void> main() async {
  /// 确保flutter framework与底层引擎的链接
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemStatusBarContrastEnforced: false,
    ),
  );

  await initializeDebugSystemProxy();

  await CrashReportingService.initialize();

  final isFirebaseAnalyticsSupported =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  if (isFirebaseAnalyticsSupported) {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  }

  await Hive.initFlutter();

  final amplitude = Amplitude(
    Configuration(
      apiKey: AmplitudeConfig.apiKey,
      minIdLength: 1,
      logLevel: kDebugMode ? LogLevel.debug : LogLevel.warn,
    ),
  );
  await amplitude.isBuilt;

  runApp(
    ProviderScope(
      retry: appProviderRetry,
      overrides: [amplitudeProvider.overrideWithValue(amplitude)],
      child: const NaloApp(),
    ),
  );
}
