// 汇总版本检查所需的安装包、设备、平台与语言信息。
// ViewModel 仅发起检查，不直接接触平台 API 或网络 Service。

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:nalo/core/device/device_id_service.dart';
import 'package:nalo/features/app_update/models/app_version_update.dart';
import 'package:nalo/features/app_update/services/app_version_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 为版本检查准备客户端上下文并调用 Service。
class AppVersionRepository {
  const AppVersionRepository({
    required AppVersionService service,
    required PackageInfo packageInfo,
    required DeviceIdService deviceIdService,
  }) : _service = service,
       _packageInfo = packageInfo,
       _deviceIdService = deviceIdService;

  final AppVersionService _service;
  final PackageInfo _packageInfo;
  final DeviceIdService _deviceIdService;

  /// 使用当前运行环境检查是否存在适用于本设备的新版本。
  Future<AppVersionUpdate> checkVersion() async {
    final deviceId = await _deviceIdService.getDeviceId();
    return _service.checkVersion(
      currentVersion: _packageInfo.version,
      platform: switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        TargetPlatform.android => 'android',
        _ => defaultTargetPlatform.name,
      },
      deviceId: deviceId,
      language: PlatformDispatcher.instance.locale.languageCode,
    );
  }
}
