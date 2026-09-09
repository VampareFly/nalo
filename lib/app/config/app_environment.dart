// 应用环境定义与运行时切换状态，供网络层和开发环境入口统一读取。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';

/// 应用运行环境，用于切换配置和第三方项目。
enum AppEnvironment { test, production }

/// 返回当前环境对应的自有业务 API 地址。
extension AppEnvironmentApiConfig on AppEnvironment {
  String get apiBaseUrl {
    return switch (this) {
      AppEnvironment.test => 'https://api-test.naloresults.com',
      AppEnvironment.production => 'https://api.naloresults.com',
    };
  }
}

/// 提供可持久化的运行时环境状态。
final appEnvironmentProvider =
    AsyncNotifierProvider<AppEnvironmentController, AppEnvironment>(
      AppEnvironmentController.new,
    );

/// 本地尚未保存选择时使用的首次启动环境；正式上线前必须改为 production。
const defaultEnvironment = AppEnvironment.test;

/// 读取、保存并切换当前运行环境。
class AppEnvironmentController extends AsyncNotifier<AppEnvironment> {
  static const _storageKey = 'app_environment';

  @override
  Future<AppEnvironment> build() async {
    final preferences = await ref.watch(sharedPreferencesProvider.future);
    return _fromStorage(preferences.getString(_storageKey));
  }

  /// 保存用户选择的环境，供 App 下次启动时初始化业务服务。
  Future<void> setEnvironment(AppEnvironment environment) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(_storageKey, environment.name);
    state = AsyncData(environment);
  }

  AppEnvironment _fromStorage(String? value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == value,
      orElse: () => defaultEnvironment,
    );
  }
}
