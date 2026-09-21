// 应用启动入口，依次完成系统 UI、基础服务、首帧配置与全局 Provider 初始化。
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nalo/app/app.dart';
import 'package:nalo/app/bootstrap/app_startup_destination.dart';
import 'package:nalo/app/config/app_environment.dart';
import 'package:nalo/app/router/app_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/analytics/amplitude_config.dart';
import 'package:nalo/core/crash_reporting/crash_reporting_service.dart';
import 'package:nalo/core/network/dio_provider.dart';
import 'package:nalo/core/network/provider_retry_policy.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';
import 'package:nalo/features/onboarding/repositories/auth_entry_config_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // TODO: <pf> Production Firebase Project 与 GA4 Property 创建后，
    // 按正式构建环境切换 Firebase 配置，避免测试与生产数据混用。
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  }

  await Hive.initFlutter();

  final preferences = await SharedPreferences.getInstance();
  final initialShowAppleLogin = readInitialShowAppleLogin(preferences);
  final initialAppLocation = await resolveAppStartupLocation(preferences);

  final bootstrapContainer = ProviderContainer(retry: appProviderRetry);
  final environment = await bootstrapContainer.read(
    appEnvironmentProvider.future,
  );
  bootstrapContainer.dispose();
  final amplitude = await createAmplitude(environment);

  runApp(
    ProviderScope(
      retry: appProviderRetry,
      overrides: [
        amplitudeProvider.overrideWithValue(amplitude),
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        initialShowAppleLoginProvider.overrideWithValue(initialShowAppleLogin),
        initialAppLocationProvider.overrideWithValue(initialAppLocation),
      ],
      child: const NaloApp(),
    ),
  );
}
