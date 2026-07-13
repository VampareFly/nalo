import 'package:shared_preferences/shared_preferences.dart';

class AppConfigRepository {
  const AppConfigRepository(this._preferences);

  static const _isFirstInstallationKey = 'is_first_installation';

  final SharedPreferences _preferences;

  bool get isFirstInstallation =>
      _preferences.getBool(_isFirstInstallationKey) ?? true;

  Future<void> markFirstInstallationCompleted() =>
      _preferences.setBool(_isFirstInstallationKey, false);
}
