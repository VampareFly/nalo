import 'package:shared_preferences/shared_preferences.dart';

/// 读写应用级本地配置。
class AppConfigRepository {
  const AppConfigRepository(this._preferences);

  static const _isFirstInstallationKey = 'is_first_installation';

  final SharedPreferences _preferences;

  /// 是否仍处于首次安装状态。
  bool get isFirstInstallation =>
      _preferences.getBool(_isFirstInstallationKey) ?? true;

  /// 标记首次安装流程已经完成。
  Future<void> markFirstInstallationCompleted() =>
      _preferences.setBool(_isFirstInstallationKey, false);
}
