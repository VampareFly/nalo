// 保存通知权限引导是否已经在首次安装启动时执行。
// 该配置只控制自动请求时机，不代表系统当前是否已授权。

import 'package:shared_preferences/shared_preferences.dart';

/// 管理通知权限首次请求的本地状态。
class NotificationPermissionRepository {
  const NotificationPermissionRepository(this._preferences);

  static const _initialRequestCompletedKey =
      'notification_initial_request_completed';

  final SharedPreferences _preferences;

  /// 是否已经执行过首次启动通知权限请求。
  bool get hasCompletedInitialRequest =>
      _preferences.getBool(_initialRequestCompletedKey) ?? false;

  /// 标记首次启动通知权限请求已经执行。
  Future<void> markInitialRequestCompleted() =>
      _preferences.setBool(_initialRequestCompletedKey, true);
}
