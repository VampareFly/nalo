// 封装系统分享面板，页面通过 Provider 调用并负责展示失败反馈。
// 分享位置由触发控件传入，确保 iPad 弹层能够正确定位。

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// 提供文本链接的系统分享能力。
class PlatformShareService {
  const PlatformShareService();

  /// 拉起系统分享面板；文案缺失时仅分享链接，平台调用失败时向上抛出异常。
  Future<void> shareLink(
    String link, {
    String? message,
    Rect? sharePositionOrigin,
  }) async {
    final normalizedMessage = message?.trim();
    final content = normalizedMessage == null || normalizedMessage.isEmpty
        ? link
        : '$normalizedMessage\n\n$link';
    await SharePlus.instance.share(
      ShareParams(
        text: content,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

/// 提供全局无状态的系统分享服务。
final platformShareServiceProvider = Provider<PlatformShareService>(
  (ref) => const PlatformShareService(),
);
