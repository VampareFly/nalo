// 统一处理 Push、Universal Link 等外部入口的页面映射与参数解析。
// 外部入口取得 target 和 action 后调用 navigate，具体路由只在本文件维护。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:nalo/app/router/app_router.dart';
import 'package:nalo/core/logging/logger_provider.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';
import 'package:nalo/features/test_flow/presentation/pages/test_flow_page.dart';

/// 提供 Push 和 Universal Link 共用的外部跳转处理器。
final commonJumpHandlerProvider = Provider<CommonJumpHandler>((ref) {
  return CommonJumpHandler(
    router: ref.read(appRouterProvider),
    logger: ref.read(loggerProvider),
    isAuthenticated: () =>
        ref.read(authSessionProvider).value?.status ==
        AuthSessionStatus.authenticated,
    isTestFlowVisible: () =>
        ref.read(testFlowVisibilityProvider).isVisible,
  );
});

/// 将外部协议中的 target 和 action 转换为项目内部路由跳转。
class CommonJumpHandler {
  /// 创建通用跳转处理器，由 Provider 注入路由和日志依赖。
  CommonJumpHandler({
    required GoRouter router,
    required Logger logger,
    required bool Function() isAuthenticated,
    required bool Function() isTestFlowVisible,
  })
    : _router = router,
      _logger = logger,
      _isAuthenticated = isAuthenticated,
      _isTestFlowVisible = isTestFlowVisible;

  static const _testFlowTarget = 'test_flow';

  final GoRouter _router;
  final Logger _logger;
  final bool Function() _isAuthenticated;
  final bool Function() _isTestFlowVisible;

  /// 解析外部跳转字段并执行白名单中的页面跳转，成功发起跳转时返回 true。
  bool navigate({required String target, String action = ''}) {
    final parameters = _parseAction(action);
    if (parameters == null) {
      _logger.w('External navigation ignored because action is invalid');
      return false;
    }
    if (!_isAuthenticated()) {
      _logger.d(
        'External navigation ignored because the user is not authenticated',
      );
      return false;
    }

    switch (target) {
      case _testFlowTarget:
        if (parameters.isNotEmpty) {
          _logger.w(
            'External navigation ignored because test_flow does not accept parameters',
          );
          return false;
        }
        if (_isTestFlowVisible()) {
          _logger.d(
            'External navigation ignored because test_flow is already visible',
          );
          return false;
        }
        unawaited(_router.push<void>(TestFlowPage.path));
        return true;
      default:
        _logger.w('External navigation ignored for unknown target: $target');
        return false;
    }
  }

  Map<String, String>? _parseAction(String action) {
    if (action.isEmpty) {
      return const {};
    }

    try {
      return Uri.splitQueryString(action);
    } on FormatException {
      return null;
    }
  }
}
