// 定义版本检查接口返回的更新信息。
// Service 负责解析，首页弹窗只消费展示、更新类型和跳转字段。

import 'package:flutter/foundation.dart';
import 'package:nalo/core/network/api_client.dart';

/// 服务端针对当前设备返回的版本更新配置。
@immutable
class AppVersionUpdate {
  const AppVersionUpdate({
    required this.hasUpdate,
    required this.latestVersion,
    required this.updateType,
    required this.releaseNotes,
    this.downloadUrl,
    this.marketUrl,
  });

  final bool hasUpdate;
  final String latestVersion;
  final int updateType;
  final List<String> releaseNotes;
  final Uri? downloadUrl;
  final Uri? marketUrl;

  /// 是否为不可跳过的强制更新。
  /// 服务端约定 `1` 为普通更新，`2` 为强制更新。
  bool get isForceUpdate => updateType == 2;

  /// 优先使用应用市场地址，缺失时回退到安装包地址。
  Uri? get updateUrl => marketUrl ?? downloadUrl;

  /// 解析版本检查接口响应。
  factory AppVersionUpdate.fromJson(Map<String, dynamic> json) {
    final hasUpdate = json['has_update'];
    final latestVersion = json['latest_version'];
    final updateType = json['update_type'];
    final notes = json['release_notes'];
    if (hasUpdate is! bool ||
        latestVersion is! String ||
        updateType is! int ||
        notes is! List) {
      throw const ResponseFormatException(
        'The version-check response has invalid fields.',
      );
    }
    return AppVersionUpdate(
      hasUpdate: hasUpdate,
      latestVersion: latestVersion.trim(),
      updateType: updateType,
      releaseNotes: notes
          .whereType<String>()
          .map((note) => note.trim())
          .where((note) => note.isNotEmpty)
          .toList(growable: false),
      downloadUrl: _parseUri(json['download_url']),
      marketUrl: _parseUri(json['market_url']),
    );
  }

  static Uri? _parseUri(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.hasScheme ? uri : null;
  }
}
