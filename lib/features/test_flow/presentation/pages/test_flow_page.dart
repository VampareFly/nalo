// 检测流程入口：根据 Provider 状态切换页面，统一上报内部页面访问并处理返回、退出确认。
// 页面组件上报具体业务行为；退出前屏蔽 reset 产生的伪页面访问。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';
import 'package:nalo/features/test_flow/presentation/pages/test_flow_screens.dart';
import 'package:nalo/features/test_flow/presentation/widgets/test_flow_widgets.dart';

/// Test Tab 进入后的完整试纸检测流程容器。
class TestFlowPage extends ConsumerStatefulWidget {
  const TestFlowPage({super.key});
  static const path = '/test';

  @override
  ConsumerState<TestFlowPage> createState() => _TestFlowPageState();
}

class _TestFlowPageState extends ConsumerState<TestFlowPage>
    with WidgetsBindingObserver {
  bool _isExiting = false;
  bool _ownsLoadingToast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reportStepEntry(ref.read(testFlowProvider));
      ref.read(testFlowProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    if (_ownsLoadingToast) EasyLoading.dismiss();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 倒计时保存的是结束时间，回到前台时同步即可得到真实剩余时长。
    if (state == AppLifecycleState.resumed) {
      ref.read(testFlowProvider.notifier).syncTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFlowProvider);
    ref.listen<TestFlowState>(testFlowProvider, (previous, next) {
      if (_isExiting || previous?.step == next.step) return;
      _reportStepEntry(next);
    });
    ref.listen(testFlowProvider.select((value) => value.isLoading), (
      previous,
      next,
    ) {
      if (next) {
        _ownsLoadingToast = true;
        EasyLoading.show();
      } else if (_ownsLoadingToast) {
        _ownsLoadingToast = false;
        EasyLoading.dismiss();
      }
    });
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack(state);
      },
      child: Scaffold(
        backgroundColor:
            state.step == TestFlowStep.capture ||
                state.step == TestFlowStep.preview ||
                state.step == TestFlowStep.milestone
            ? flowInk
            : flowPaper,
        body: Stack(
          fit: StackFit.expand,
          children: [
            switch (state.step) {
              TestFlowStep.about => AboutTestScreen(onClose: _exitFromAbout),
              TestFlowStep.beforeStart => BeforeStartScreen(
                onBack: _backFromBeforeStart,
              ),
              TestFlowStep.swab || TestFlowStep.dip || TestFlowStep.develop =>
                TestTimerScreen(onBack: _backFromTimer, onExit: _requestExit),
              TestFlowStep.capture => CaptureScreen(onClose: _requestExit),
              TestFlowStep.preview => PhotoPreviewScreen(
                onBack: () => _retake(AnalyticsPhotoRetakeMethod.topBack),
              ),
              TestFlowStep.confirm => ConfirmResultScreen(
                onClose: _requestExit,
              ),
              TestFlowStep.milestone => const MilestoneScreen(),
              TestFlowStep.result => ResultDetailsScreen(
                onClose: _exitAfterCompletion,
                onBackHome: _exitAfterCompletion,
              ),
            },
          ],
        ),
      ),
    );
  }

  /// 将系统返回行为映射到当前检测节点的产品交互。
  void _handleSystemBack(TestFlowState state) {
    if (state.isLoading) return;
    switch (state.step) {
      case TestFlowStep.about:
        _exitFromAbout();
        return;
      case TestFlowStep.beforeStart:
        _backFromBeforeStart();
        return;
      case TestFlowStep.swab:
      case TestFlowStep.dip:
      case TestFlowStep.develop:
        _backFromTimer();
        return;
      case TestFlowStep.preview:
        _retake(AnalyticsPhotoRetakeMethod.systemBack);
        return;
      case TestFlowStep.confirm:
        _requestExit();
        return;
      case TestFlowStep.result:
        _exitAfterCompletion();
        return;
      default:
        _requestExit();
        return;
    }
  }

  void _reportStepEntry(TestFlowState state) {
    final pageName = _analyticsPageName(state.step);
    if (pageName == null) return;
    unawaited(ref.reportAnalyticsPageView(pageName));
    if (!_isTimerStep(state.step)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testTimerView,
        properties: {
          AnalyticsEventProperty.pageName: pageName.value,
          AnalyticsEventProperty.detectionType: _analyticsDetectionType(
            state.type,
          ).value,
          AnalyticsEventProperty.desc: _timerDescription(state.step),
          AnalyticsEventProperty.timerDurationSeconds:
              state.timerDuration.inSeconds,
          AnalyticsEventProperty.remainingSeconds:
              (state.remaining.inMilliseconds / 1000).ceil(),
          AnalyticsEventProperty.timerStatus: _analyticsTimerStatus(
            state.timerStatus,
          ).value,
        },
      ),
    );
  }

  void _exitFromAbout() {
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testFlowExitClick,
        properties: _flowProperties(state),
      ),
    );
    _exitWithoutPrompt();
  }

  void _backFromBeforeStart() {
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testFlowBackClick,
        properties: _flowProperties(state),
      ),
    );
    _setStep(TestFlowStep.about);
  }

  void _backFromTimer() {
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testFlowBackClick,
        properties: _flowProperties(state),
      ),
    );
    ref.read(testFlowProvider.notifier).previousTimerStep();
  }

  void _retake(AnalyticsPhotoRetakeMethod method) {
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testPhotoRetakeClick,
        properties: {
          ..._flowProperties(state),
          AnalyticsEventProperty.method: method.value,
        },
      ),
    );
    ref.read(testFlowProvider.notifier).retake();
  }

  void _requestExit() {
    final state = ref.read(testFlowProvider);
    if (_analyticsPageName(state.step) == null ||
        state.step == TestFlowStep.milestone) {
      unawaited(_confirmExit(reportAnalytics: false));
      return;
    }
    unawaited(
      ref.report(
        AnalyticsEvent.testFlowExitClick,
        properties: _flowProperties(state),
      ),
    );
    unawaited(_confirmExit());
  }

  /// 处理允许回退的页面节点，避免外部直接修改 Provider 状态。
  void _setStep(TestFlowStep step) {
    final controller = ref.read(testFlowProvider.notifier);
    if (step == TestFlowStep.about) {
      controller.reset();
      controller.initialize();
    } else if (step == TestFlowStep.preview) {
      final path = ref.read(testFlowProvider).photoPath;
      if (path != null) controller.setPhoto(path);
    }
  }

  /// 检测未完成时展示底部退出确认，确认后丢弃本次进度。
  Future<void> _confirmExit({bool reportAnalytics = true}) async {
    if (ref.read(testFlowProvider).isLoading) return;
    final state = ref.read(testFlowProvider);
    const title = 'Exit test?';
    const desc =
        'Your progress on this step will be lost. You can restart the test from the beginning.';
    if (reportAnalytics) {
      unawaited(
        ref.report(
          AnalyticsEvent.testExitAlertView,
          properties: {
            ..._flowProperties(state),
            AnalyticsEventProperty.title: title,
            AnalyticsEventProperty.desc: desc,
          },
        ),
      );
    }
    final shouldExit = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      barrierColor: flowInk.withValues(alpha: 0.6),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ExitTestSheet(),
    );
    if (!mounted) return;
    if (reportAnalytics) {
      unawaited(
        ref.report(
          AnalyticsEvent.testExitAlertClick,
          properties: {
            ..._flowProperties(state),
            AnalyticsEventProperty.action: shouldExit == true
                ? AnalyticsTestExitAction.exit.value
                : AnalyticsTestExitAction.keepTesting.value,
          },
        ),
      );
    }
    if (shouldExit == true && mounted) _exitWithoutPrompt();
  }

  void _exitWithoutPrompt() {
    _isExiting = true;
    ref.read(testFlowProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  void _exitAfterCompletion() {
    _isExiting = true;
    ref.read(testFlowProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  Map<AnalyticsEventProperty, Object> _flowProperties(TestFlowState state) {
    final pageName = _analyticsPageName(state.step);
    return {
      AnalyticsEventProperty.pageName: pageName?.value ?? '',
      AnalyticsEventProperty.detectionType: _analyticsDetectionType(
        state.type,
      ).value,
    };
  }
}

AnalyticsPageName? _analyticsPageName(TestFlowStep step) {
  return switch (step) {
    TestFlowStep.about => AnalyticsPageName.testAbout,
    TestFlowStep.beforeStart => AnalyticsPageName.testBeforeStart,
    TestFlowStep.swab => AnalyticsPageName.testSwab,
    TestFlowStep.dip => AnalyticsPageName.testDip,
    TestFlowStep.develop => AnalyticsPageName.testDevelop,
    TestFlowStep.capture => AnalyticsPageName.testCapture,
    TestFlowStep.preview => AnalyticsPageName.testPhotoPreview,
    TestFlowStep.confirm => AnalyticsPageName.testResultConfirm,
    TestFlowStep.milestone => AnalyticsPageName.testCelebration,
    TestFlowStep.result => AnalyticsPageName.testResult,
    _ => null,
  };
}

AnalyticsDetectionType _analyticsDetectionType(DetectionType type) {
  return switch (type) {
    DetectionType.cortisol => AnalyticsDetectionType.cortisol,
    DetectionType.testosterone => AnalyticsDetectionType.testosterone,
  };
}

bool _isTimerStep(TestFlowStep step) {
  return step == TestFlowStep.swab ||
      step == TestFlowStep.dip ||
      step == TestFlowStep.develop;
}

String _timerDescription(TestFlowStep step) {
  return switch (step) {
    TestFlowStep.swab => 'Rub the swab under your tongue for 15 seconds.',
    TestFlowStep.dip => 'Dip the strip into the saliva sample for 30 seconds.',
    TestFlowStep.develop =>
      'Wait 15 minutes while the strip develops. Knowledge incoming.',
    _ => '',
  };
}

AnalyticsTimerStatus _analyticsTimerStatus(TimerStatus status) {
  return switch (status) {
    TimerStatus.running => AnalyticsTimerStatus.running,
    TimerStatus.paused => AnalyticsTimerStatus.paused,
    TimerStatus.complete || TimerStatus.idle => AnalyticsTimerStatus.complete,
  };
}

/// 按 Figma 样式展示检测中途退出确认，并保持底部安全区为白色。
class _ExitTestSheet extends StatelessWidget {
  const _ExitTestSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 20),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFF0D4D4),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD4183D),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Exit test?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: flowInk,
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your progress on this step will be lost. You can restart the test from the beginning.',
            textAlign: TextAlign.center,
            style: TextStyle(color: flowMuted, fontSize: 14, height: 20 / 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4183D),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Yes, exit test'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: flowBlue,
                side: const BorderSide(color: flowBlue, width: 1.5),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Keep going'),
            ),
          ),
        ],
      ),
    ),
  );
}
