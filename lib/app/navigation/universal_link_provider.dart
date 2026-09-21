// 监听 iOS Universal Link，并将校验后的 target/action 转交给统一跳转处理器。
// Provider 随应用根节点启动和销毁，只接受项目已配置域名的 HTTPS 链接。

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/app/navigation/common_jump_handler.dart';
import 'package:nalo/app/navigation/initial_page_ready_provider.dart';
import 'package:nalo/core/logging/logger_provider.dart';

/// 提供应用进程内共享的 Universal Link 监听生命周期。
final universalLinkProvider = NotifierProvider<UniversalLinkNotifier, void>(
  UniversalLinkNotifier.new,
);

/// 校验并转发 iOS Universal Link，不在本层维护页面路由映射。
class UniversalLinkNotifier extends Notifier<void> {
  static const _allowedHosts = {
    'api-test.naloresults.com',
    'api.naloresults.com',
  };
  Uri? _pendingColdStartLink;

  @override
  void build() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    ref.listen<bool>(initialPageReadyProvider, (_, isReady) {
      if (isReady) _handleInitialPageReady();
    });

    final subscription = AppLinks().uriLinkStream.listen(
      _handleLink,
      onError: (Object error, StackTrace stackTrace) {
        ref
            .read(loggerProvider)
            .e(
              'Universal Link stream failed.',
              error: error,
              stackTrace: stackTrace,
            );
      },
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
  }

  void _handleLink(Uri uri) {
    if (uri.scheme != 'https' || !_allowedHosts.contains(uri.host)) {
      ref.read(loggerProvider).w('Universal Link ignored for unknown origin.');
      return;
    }

    final target = uri.queryParameters['target']?.trim();
    if (target == null || target.isEmpty) {
      ref
          .read(loggerProvider)
          .w('Universal Link ignored because target is missing.');
      return;
    }

    if (!ref.read(initialPageReadyProvider)) {
      _pendingColdStartLink = uri;
      return;
    }
    _navigate(uri);
  }

  void _handleInitialPageReady() {
    final uri = _pendingColdStartLink;
    _pendingColdStartLink = null;
    if (uri != null) _navigate(uri);
  }

  void _navigate(Uri uri) {
    final target = uri.queryParameters['target']?.trim();
    if (target == null || target.isEmpty) return;
    ref.read(commonJumpHandlerProvider).navigate(
      target: target,
      action: uri.queryParameters['action'] ?? '',
    );
  }
}
