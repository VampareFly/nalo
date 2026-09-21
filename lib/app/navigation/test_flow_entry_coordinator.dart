// 检测流程入口协调器：统一上报入口点击并携带固定 source 打开检测路由。
// 页面按钮、Universal Link 与 Push 均通过本入口进入，流程内部继续从 TestFlowState 读取 source。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/app/router/app_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/test_flow/presentation/pages/test_flow_page.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';

/// 提供所有检测入口共用的跳转与入口埋点能力。
final testFlowEntryCoordinatorProvider = Provider<TestFlowEntryCoordinator>((
  ref,
) {
  return TestFlowEntryCoordinator(
    router: ref.read(appRouterProvider),
    analytics: ref.read(analyticsProvider),
    testFlowController: ref.read(testFlowProvider.notifier),
  );
});

/// 在进入 Test Flow 前同时确定来源、上报入口事件并完成跳转。
class TestFlowEntryCoordinator {
  /// 创建入口协调器，由 Provider 注入路由与统一分析服务。
  const TestFlowEntryCoordinator({
    required GoRouter router,
    required AnalyticsService analytics,
    required TestFlowController testFlowController,
  }) : _router = router,
       _analytics = analytics,
       _testFlowController = testFlowController;

  final GoRouter _router;
  final AnalyticsService _analytics;
  final TestFlowController _testFlowController;

  /// 从指定入口打开检测流程；入口属性缺失时不发送对应可选字段。
  Future<void> open({
    required AnalyticsTestFlowSource source,
    AnalyticsPageName? pageName,
    AnalyticsTestStartPosition? position,
    int? totalTestCount,
  }) async {
    _testFlowController.beginSession(source);
    unawaited(
      _analytics.report(
        AnalyticsEvent.testStartEntryClick,
        properties: {
          AnalyticsEventProperty.source: source.value,
          if (pageName != null) AnalyticsEventProperty.pageName: pageName.value,
          if (position != null) AnalyticsEventProperty.position: position.value,
          if (totalTestCount != null)
            AnalyticsEventProperty.totalTestCount: totalTestCount,
        },
      ),
    );
    try {
      await _router.push<void>(TestFlowPage.path);
    } finally {
      _testFlowController.endSession();
    }
  }
}
