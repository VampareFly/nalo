// 应用版本信息 Provider，从原生安装包读取版本名和构建号供 UI 展示。
// 页面通过监听 appVersionLabelProvider 获取格式化后的版本文案。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 提供当前安装包的完整版本信息。
final appPackageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// 提供当前安装包的版本名和构建号，例如 `v1.0.0 (1)`。
final appVersionLabelProvider = Provider<AsyncValue<String>>((ref) {
  return ref.watch(appPackageInfoProvider).whenData(
    (packageInfo) => 'v${packageInfo.version} (${packageInfo.buildNumber})',
  );
});
