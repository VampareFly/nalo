// Amplitude 环境配置：维护环境与项目 Key 的映射，并统一创建已初始化的 SDK 实例。
// App 启动和运行时环境切换均通过本文件创建对应项目的客户端。

import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:nalo/app/config/app_environment.dart';

/// 根据当前应用环境提供对应的 Amplitude API Key。
class AmplitudeConfig {
  const AmplitudeConfig._();

  /// 返回指定环境使用的项目 Key。
  static String apiKeyFor(AppEnvironment environment) => switch (environment) {
    /// 测试环境
    AppEnvironment.test => '69356ab428cc8ff66ec27555d15d6217',

    /// 生产环境
    AppEnvironment.production => 'f3df996f87b4cf5d7ffd40dbcff92aef',
  };
}

/// 创建并等待指定环境的 Amplitude 客户端完成初始化。
Future<Amplitude> createAmplitude(AppEnvironment environment) async {
  final amplitude = Amplitude(
    Configuration(
      apiKey: AmplitudeConfig.apiKeyFor(environment),
      minIdLength: 1,
      logLevel: kDebugMode ? LogLevel.debug : LogLevel.warn,
    ),
  );
  await amplitude.isBuilt;
  return amplitude;
}
