// 统一处理 Push、Universal Link 等外部入口的页面映射与参数解析。
// 外部入口取得 target 和 action 后调用 navigate，具体路由只在本文件维护。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:nalo/app/navigation/test_flow_entry_coordinator.dart';
import 'package:nalo/app/router/app_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/logging/logger_provider.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';

/// 提供 Push 和 Universal Link 共用的外部跳转处理器。
final commonJumpHandlerProvider = Provider<CommonJumpHandler>((ref) {
  return CommonJumpHandler(
    router: ref.read(appRouterProvider),
    testFlowEntryCoordinator: ref.read(testFlowEntryCoordinatorProvider),
    logger: ref.read(loggerProvider),
    isAuthenticated: () =>
        ref.read(authSessionProvider).value?.status ==
        AuthSessionStatus.authenticated,
    isTestFlowVisible: () => ref.read(testFlowVisibilityProvider).isVisible,
  );
});

/// 将外部协议中的 target 和 action 转换为项目内部路由跳转。
class CommonJumpHandler {
  /// 创建通用跳转处理器，由 Provider 注入路由和日志依赖。
  CommonJumpHandler({
    required GoRouter router,
    required TestFlowEntryCoordinator testFlowEntryCoordinator,
    required Logger logger,
    required bool Function() isAuthenticated,
    required bool Function() isTestFlowVisible,
  }) : _router = router,
       _testFlowEntryCoordinator = testFlowEntryCoordinator,
       _logger = logger,
       _isAuthenticated = isAuthenticated,
       _isTestFlowVisible = isTestFlowVisible;

  static const _testFlowTarget = 'test_flow';
  static const _homeTabTarget = 'tab_home';
  static const _shopTabTarget = 'tab_shop';

  final GoRouter _router;
  final TestFlowEntryCoordinator _testFlowEntryCoordinator;
  final Logger _logger;
  final bool Function() _isAuthenticated;
  final bool Function() _isTestFlowVisible;

  /// 解析外部跳转字段并执行白名单中的页面跳转，成功发起跳转时返回 true。
  bool navigate({
    required String target,
    String action = '',
    AnalyticsTestFlowSource source = AnalyticsTestFlowSource.commonLink,
  }) {
    if (!_isAuthenticated()) {
      _logger.d(
        'External navigation ignored because the user is not authenticated',
      );
      return false;
    }
    if (_isTestFlowVisible()) {
      _logger.d(
        'External navigation ignored because test_flow is already visible',
      );
      return false;
    }

    switch (target) {
      case _testFlowTarget:
        unawaited(_testFlowEntryCoordinator.open(source: source));
        return true;
      case _homeTabTarget:
        _router.go(HomePage.externalTabLocation(shop: false));
        return true;
      case _shopTabTarget:
        _router.go(HomePage.externalTabLocation(shop: true));
        return true;
      default:
        _logger.w('External navigation ignored for unknown target: $target');
        return false;
    }
  }
}
