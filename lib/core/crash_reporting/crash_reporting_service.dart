// Crashlytics 崩溃上报服务，负责初始化收集策略、注册全局异常处理和触发测试崩溃。
// 应用启动时初始化；测试版本可从欢迎页主动制造崩溃以检查 Firebase 与 dSYM 配置。


import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 用于隔离测试崩溃数据并控制测试入口显示的版本号。
const crashlyticsTestVersion = '9.9.9';

/// 管理 Firebase Crashlytics 初始化和全局异常上报。
class CrashReportingService {
  const CrashReportingService._();

  /// 在应用启动阶段初始化移动端 Crashlytics，并根据构建模式和版本决定是否收集。
  static Future<void> initialize() async {
    final isSupportedPlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    if (!isSupportedPlatform) return;

    await Firebase.initializeApp();

    final packageInfo = await PackageInfo.fromPlatform();
    final collectionEnabled =
        kReleaseMode || packageInfo.version == crashlyticsTestVersion;

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      collectionEnabled,
    );

    if (!collectionEnabled) return;

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// 记录测试上下文后触发原生崩溃，用于检查崩溃上报和符号化结果。
  static Future<void> triggerTestCrash() async {
    await FirebaseCrashlytics.instance.setCustomKey('test_crash', true);
    FirebaseCrashlytics.instance.log('Manual Crashlytics test crash');
    FirebaseCrashlytics.instance.crash();
  }
}
