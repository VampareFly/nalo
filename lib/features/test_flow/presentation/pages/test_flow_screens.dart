// 检测流程页面集合：渲染各步骤 UI，并上报页面内点击、曝光及结果交互。
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/sharing/platform_share_service.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';
import 'package:nalo/features/test_flow/presentation/widgets/native_camera_view.dart';
import 'package:nalo/features/test_flow/presentation/widgets/test_flow_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _analyticsVisibleFraction = 0.1;
const _celebrationDescription =
    'Consistent testing is everything. Each result builds a clearer picture '
    'of your hormone patterns over time. Keep going — your data is working for you.';
const _testAgainDescription =
    'Patterns build over time. The more you test, the clearer the picture.';

/// 展示检测类型选择、注意事项和最近三次结果。
class AboutTestScreen extends ConsumerStatefulWidget {
  const AboutTestScreen({required this.onClose, super.key});
  final VoidCallback onClose;

  @override
  ConsumerState<AboutTestScreen> createState() => _AboutTestScreenState();
}

class _AboutTestScreenState extends ConsumerState<AboutTestScreen> {
  final Set<String> _viewedSections = {};
  final Set<String> _viewedItems = {};

  void _selectType(DetectionType type) {
    unawaited(
      ref.report(
        AnalyticsEvent.testTypeClick,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.testAbout.value,
          AnalyticsEventProperty.detectionType: _analyticsDetectionType(
            type,
          ).value,
        },
      ),
    );
    unawaited(ref.read(testFlowProvider.notifier).selectType(type));
  }

  void _startTest(TestFlowState state) {
    unawaited(
      ref.report(
        AnalyticsEvent.testStartClick,
        properties: _testFlowProperties(
          AnalyticsPageName.testAbout,
          state.type,
        ),
      ),
    );
    ref.read(testFlowProvider.notifier).showBeforeStart();
  }

  void _reportSectionView(TestFlowState state, double visibleFraction) {
    if (state.isLoading || visibleFraction < _analyticsVisibleFraction) return;
    final detectionType = _analyticsDetectionType(state.type);
    final key = '${AnalyticsPageName.testAbout.value}:${detectionType.value}';
    if (!_viewedSections.add(key)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultSectionView,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testAbout, state.type),
          AnalyticsEventProperty.itemCount: state.recent.length,
          AnalyticsEventProperty.position: 1,
        },
      ),
    );
  }

  void _reportItemView(
    RecentDetection item,
    DetectionType type,
    int position,
    double visibleFraction,
  ) {
    if (visibleFraction < _analyticsVisibleFraction) return;
    final detectionType = _analyticsDetectionType(type);
    final testId = item.id.toString();
    final key =
        '${AnalyticsPageName.testAbout.value}:${detectionType.value}:$testId';
    if (!_viewedItems.add(key)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultItemView,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testAbout, type),
          AnalyticsEventProperty.testId: testId,
          AnalyticsEventProperty.position: position,
          AnalyticsEventProperty.date: item.date,
          AnalyticsEventProperty.timePeriod: item.period,
          AnalyticsEventProperty.value: item.value,
          AnalyticsEventProperty.unit: item.unit,
          AnalyticsEventProperty.typicalRange: item.typicalRange,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFlowProvider);
    return _PaperPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowTopBar(onClose: widget.onClose, center: const FlowNaloMark()),
          const SizedBox(height: 24),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'About your\n'),
                TextSpan(
                  text: 'saliva kit.',
                  style: TextStyle(color: flowBlue),
                ),
              ],
            ),
            style: TextStyle(
              color: flowInk,
              fontSize: 30,
              height: 36 / 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Each test gives you a single snapshot of your hormone levels.',
            style: TextStyle(color: flowMuted, fontSize: 14, height: 20 / 14),
          ),
          const SizedBox(height: 24),
          const FlowCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, color: Color(0xFFF5A623), size: 18),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best time to test',
                        style: TextStyle(
                          color: flowInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Morning (1 hour after waking up) is ideal for cortisol. Consistency matters most.',
                        style: TextStyle(
                          color: flowMuted,
                          fontSize: 12,
                          height: 16 / 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'What are you testing?',
            style: TextStyle(
              color: flowInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  type: DetectionType.cortisol,
                  selected: state.type == DetectionType.cortisol,
                  onPressed: _selectType,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeButton(
                  type: DetectionType.testosterone,
                  selected: state.type == DetectionType.testosterone,
                  onPressed: _selectType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VisibilityDetector(
                  key: ValueKey('test-about-section-${state.type.name}'),
                  onVisibilityChanged: (info) =>
                      _reportSectionView(state, info.visibleFraction),
                  child: const FlowSectionLabel('Last 3 tests'),
                ),
                const SizedBox(height: 12),
                RecentResultsList(
                  items: state.recent,
                  type: state.type,
                  shrinkWrap: true,
                  onItemVisibilityChanged: _reportItemView,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FlowPrimaryButton(
            label: 'Start test',
            onPressed: () => _startTest(state),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.type,
    required this.selected,
    required this.onPressed,
  });
  final DetectionType type;
  final bool selected;
  final ValueChanged<DetectionType> onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton(
      onPressed: () => onPressed(type),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? flowBlue : Colors.white,
        foregroundColor: selected ? Colors.white : flowBlue,
        side: const BorderSide(color: flowBlue, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Text(type.label),
    ),
  );
}

/// 在检测介绍页和结果页复用的最近三次检测列表。
class RecentResultsList extends StatelessWidget {
  const RecentResultsList({
    required this.items,
    required this.type,
    this.shrinkWrap = false,
    this.onItemVisibilityChanged,
    super.key,
  });
  final List<RecentDetection> items;
  final DetectionType type;
  final bool shrinkWrap;
  final void Function(RecentDetection, DetectionType, int, double)?
  onItemVisibilityChanged;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFEDEAE4),
              child: Icon(Icons.schedule, color: Color(0xFFB8B3AA), size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${type.label.toLowerCase()} tests yet.',
              style: const TextStyle(color: flowMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = items[index];
        final row = Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.date,
                      style: const TextStyle(
                        color: flowInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      item.period,
                      style: const TextStyle(color: flowMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.value} ${item.unit}',
                style: const TextStyle(
                  color: flowInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
        final onVisibilityChanged = this.onItemVisibilityChanged;
        if (onVisibilityChanged == null) return row;
        return VisibilityDetector(
          key: ValueKey('test-about-item-${type.name}-${item.id}'),
          onVisibilityChanged: (info) =>
              onVisibilityChanged(item, type, index + 1, info.visibleFraction),
          child: row,
        );
      },
    );
  }
}

/// 展示正式检测开始前的准备要求。
class BeforeStartScreen extends ConsumerStatefulWidget {
  const BeforeStartScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  ConsumerState<BeforeStartScreen> createState() => _BeforeStartScreenState();
}

class _BeforeStartScreenState extends ConsumerState<BeforeStartScreen> {
  final Set<int> _viewedTips = {};

  void _reportTip(
    TestFlowState state,
    int position,
    String title,
    String desc,
    double visibleFraction,
  ) {
    if (visibleFraction < _analyticsVisibleFraction ||
        !_viewedTips.add(position)) {
      return;
    }
    unawaited(
      ref.report(
        AnalyticsEvent.testPreparationTipView,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testBeforeStart, state.type),
          AnalyticsEventProperty.position: position,
          AnalyticsEventProperty.title: title,
          AnalyticsEventProperty.desc: desc,
        },
      ),
    );
  }

  void _beginSwab(TestFlowState state) {
    unawaited(
      ref.report(
        AnalyticsEvent.testReadyClick,
        properties: _testFlowProperties(
          AnalyticsPageName.testBeforeStart,
          state.type,
        ),
      ),
    );
    ref.read(testFlowProvider.notifier).beginSwab();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFlowProvider);
    const firstTitle = 'No eating, drinking or brushing';
    const firstDesc = 'for 30 minutes before the test.';
    const secondTitle = 'Test at the same time';
    const secondDesc =
        'For the most consistent results, test at the same time of day each time.';
    return _PaperPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowTopBar(onBack: widget.onBack),
          const SizedBox(height: 24),
          const Text(
            'Before you start.',
            style: TextStyle(
              color: flowInk,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          VisibilityDetector(
            key: const ValueKey('test-preparation-tip-1'),
            onVisibilityChanged: (info) => _reportTip(
              state,
              1,
              firstTitle,
              firstDesc,
              info.visibleFraction,
            ),
            child: const _PreparationCard(
              icon: Icons.schedule,
              iconColor: flowBlue,
              title: firstTitle,
              body: firstDesc,
            ),
          ),
          const SizedBox(height: 16),
          VisibilityDetector(
            key: const ValueKey('test-preparation-tip-2'),
            onVisibilityChanged: (info) => _reportTip(
              state,
              2,
              secondTitle,
              secondDesc,
              info.visibleFraction,
            ),
            child: const _PreparationCard(
              icon: Icons.notifications_none,
              iconColor: Color(0xFFF5A623),
              title: secondTitle,
              body: secondDesc,
            ),
          ),
          const Spacer(),
          FlowPrimaryButton(
            label: "Ready, let's go",
            onPressed: () => _beginSwab(state),
          ),
        ],
      ),
    );
  }
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => FlowCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: flowInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                body,
                style: const TextStyle(
                  color: flowMuted,
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 复用展示采样、浸泡和显色三个计时步骤。
class TestTimerScreen extends ConsumerWidget {
  const TestTimerScreen({
    required this.onBack,
    required this.onExit,
    super.key,
  });
  final VoidCallback onBack;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testFlowProvider);
    final controller = ref.read(testFlowProvider.notifier);
    final isDevelop = state.step == TestFlowStep.develop;
    final active = state.step == TestFlowStep.swab
        ? 0
        : state.step == TestFlowStep.dip
        ? 1
        : 2;
    final instruction = switch (state.step) {
      TestFlowStep.swab => 'Rub the swab under your tongue for 15 seconds.',
      TestFlowStep.dip =>
        'Dip the strip into the saliva sample for 30 seconds.',
      _ => 'Wait 15 minutes while the strip develops. Knowledge incoming.',
    };
    return _PaperPage(
      child: Column(
        children: [
          FlowTopBar(
            onBack: onBack,
            onClose: onExit,
            center: FlowStepPills(activeIndex: active),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 224,
                  height: 160,
                  decoration: BoxDecoration(
                    color: isDevelop ? flowYellow : flowSoftBlue,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: FlowNaloMark(
                      color: isDevelop ? const Color(0xFFF5B843) : flowYellow,
                      width: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 320,
                  child: Text(
                    instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: flowMuted,
                      fontSize: 14,
                      height: 20 / 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _TimerRing(state: state),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: state.timerStatus == TimerStatus.paused
                      ? () {
                          _reportTimerClick(
                            ref,
                            state,
                            AnalyticsTimerAction.resume,
                          );
                          controller.resumeTimer();
                        }
                      : () => _pause(context, ref, isDevelop),
                  child: Text(
                    state.timerStatus == TimerStatus.paused
                        ? 'Resume'
                        : 'Pause',
                    style: const TextStyle(
                      color: flowBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: flowBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.timerStatus == TimerStatus.complete)
            FlowPrimaryButton(
              label: 'Next',
              onPressed: () {
                _reportTimerClick(ref, state, AnalyticsTimerAction.next);
                controller.nextAfterTimer();
              },
            )
          else
            FlowOutlineButton(
              label: 'Skip timer',
              onPressed: () => _skip(context, ref, isDevelop),
            ),
        ],
      ),
    );
  }

  /// 显色阶段暂停前提示试纸仍会继续显色。
  Future<void> _pause(BuildContext context, WidgetRef ref, bool warning) async {
    final state = ref.read(testFlowProvider);
    if (warning) {
      const title = 'Pause timer?';
      const desc =
          'The strip will continue developing while the timer is paused.';
      _reportTimerAlertView(
        ref,
        state,
        AnalyticsTimerAlertAction.pause,
        title,
        desc,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) =>
            const _RiskDialog(title: title, body: desc, confirm: 'Pause'),
      );
      if (!context.mounted) return;
      _reportTimerAlertClick(
        ref,
        state,
        AnalyticsTimerAlertAction.pause,
        confirmed == true,
      );
      if (confirmed != true) return;
    }
    _reportTimerClick(ref, state, AnalyticsTimerAction.pause);
    ref.read(testFlowProvider.notifier).pauseTimer();
  }

  /// 显色阶段跳过前要求用户确认已实际等待满十五分钟。
  Future<void> _skip(BuildContext context, WidgetRef ref, bool warning) async {
    final state = ref.read(testFlowProvider);
    if (warning) {
      const title = 'Skip timer?';
      const desc =
          'Only continue if the strip has already developed for the full 15 minutes.';
      _reportTimerAlertView(
        ref,
        state,
        AnalyticsTimerAlertAction.skip,
        title,
        desc,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) =>
            const _RiskDialog(title: title, body: desc, confirm: 'Continue'),
      );
      if (!context.mounted) return;
      _reportTimerAlertClick(
        ref,
        state,
        AnalyticsTimerAlertAction.skip,
        confirmed == true,
      );
      if (confirmed != true) return;
    }
    _reportTimerClick(ref, state, AnalyticsTimerAction.skip);
    ref.read(testFlowProvider.notifier).skipTimer();
  }

  void _reportTimerClick(
    WidgetRef ref,
    TestFlowState state,
    AnalyticsTimerAction action,
  ) {
    unawaited(
      ref.report(
        AnalyticsEvent.testTimerClick,
        properties: {
          ..._testFlowProperties(_timerPageName(state.step), state.type),
          AnalyticsEventProperty.action: action.value,
          AnalyticsEventProperty.timerDurationSeconds:
              state.timerDuration.inSeconds,
          AnalyticsEventProperty.remainingSeconds: _remainingSeconds(
            state.remaining,
          ),
        },
      ),
    );
  }

  void _reportTimerAlertView(
    WidgetRef ref,
    TestFlowState state,
    AnalyticsTimerAlertAction timerAction,
    String title,
    String desc,
  ) {
    unawaited(
      ref.report(
        AnalyticsEvent.testTimerAlertView,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testDevelop, state.type),
          AnalyticsEventProperty.timerAction: timerAction.value,
          AnalyticsEventProperty.title: title,
          AnalyticsEventProperty.desc: desc,
        },
      ),
    );
  }

  void _reportTimerAlertClick(
    WidgetRef ref,
    TestFlowState state,
    AnalyticsTimerAlertAction timerAction,
    bool confirmed,
  ) {
    unawaited(
      ref.report(
        AnalyticsEvent.testTimerAlertClick,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testDevelop, state.type),
          AnalyticsEventProperty.timerAction: timerAction.value,
          AnalyticsEventProperty.action: confirmed
              ? AnalyticsConfirmationAction.confirm.value
              : AnalyticsConfirmationAction.cancel.value,
        },
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({required this.state});
  final TestFlowState state;
  @override
  Widget build(BuildContext context) {
    final total = state.timerDuration.inMilliseconds;
    final value = total == 0
        ? 0.0
        : (state.remaining.inMilliseconds / total).clamp(0.0, 1.0);
    final seconds = (state.remaining.inMilliseconds / 1000).ceil();
    final text = state.timerDuration.inMinutes >= 1
        ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
        : '${seconds}s';
    final unit = state.timerDuration.inMinutes >= 1 ? 'minutes' : 'seconds';
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 7,
              color: flowBlue,
              backgroundColor: flowBlue.withValues(alpha: .12),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: flowBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(color: flowMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskDialog extends StatelessWidget {
  const _RiskDialog({
    required this.title,
    required this.body,
    required this.confirm,
  });
  final String title;
  final String body;
  final String confirm;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(confirm),
      ),
    ],
  );
}

/// 在 App 内完成相机授权、取景和试纸拍摄。
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({required this.onClose, super.key});
  final VoidCallback onClose;
  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  final NativeCameraController _camera = NativeCameraController();
  CameraPermissionState _permission = CameraPermissionState.loading;
  bool _initializing = false;
  bool _cameraReady = false;
  bool _capturing = false;
  bool _cameraInitResultReported = false;
  bool _guideReported = false;
  Key _cameraViewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // CaptureScreen 可能因检测流程 Provider 切换步骤而在同一构建帧挂载；
    // 延迟初始化可避免在 initState 中再次修改 Provider。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 用户从系统设置返回时重新读取相机权限并恢复预览。
    if (state == AppLifecycleState.resumed) _initialize();
  }

  /// 请求系统相机权限；权限通过后由原生 Platform View 启动相机会话。
  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    if (mounted) {
      setState(() {
        _permission = CameraPermissionState.loading;
        _cameraReady = false;
        _cameraInitResultReported = false;
        _cameraViewKey = UniqueKey();
      });
    }
    try {
      if (Platform.isIOS) {
        final status = await NativeCameraController.requestIosPermission();
        if (!mounted) return;
        final permission = switch (status) {
          NativeCameraPermissionStatus.granted => CameraPermissionState.ready,
          NativeCameraPermissionStatus.denied ||
          NativeCameraPermissionStatus.restricted =>
            CameraPermissionState.permanentlyDenied,
        };
        _reportPermissionResult(
          status == NativeCameraPermissionStatus.granted
              ? AnalyticsCameraPermissionStatus.granted
              : AnalyticsCameraPermissionStatus.permanentlyDeniedOrRestricted,
          isSuccess: status == NativeCameraPermissionStatus.granted,
          failReason: switch (status) {
            NativeCameraPermissionStatus.granted => '',
            NativeCameraPermissionStatus.denied =>
              'permission_permanently_denied: Camera permission permanently denied',
            NativeCameraPermissionStatus.restricted =>
              'permission_restricted: Camera permission restricted',
          },
        );
        setState(() => _permission = permission);
        return;
      }
      var status = await Permission.camera.status;
      if (status.isDenied) status = await Permission.camera.request();
      if (!mounted) return;
      final permission = switch (status) {
        PermissionStatus.granted => CameraPermissionState.ready,
        PermissionStatus.permanentlyDenied ||
        PermissionStatus.restricted => CameraPermissionState.permanentlyDenied,
        _ => CameraPermissionState.denied,
      };
      final analyticsStatus = switch (status) {
        PermissionStatus.granted => AnalyticsCameraPermissionStatus.granted,
        PermissionStatus.permanentlyDenied || PermissionStatus.restricted =>
          AnalyticsCameraPermissionStatus.permanentlyDeniedOrRestricted,
        _ => AnalyticsCameraPermissionStatus.denied,
      };
      _reportPermissionResult(
        analyticsStatus,
        isSuccess: status == PermissionStatus.granted,
        failReason: switch (status) {
          PermissionStatus.granted => '',
          PermissionStatus.permanentlyDenied =>
            'permission_permanently_denied: Camera permission permanently denied',
          PermissionStatus.restricted =>
            'permission_restricted: Camera permission restricted',
          _ => 'permission_denied: Camera permission denied',
        },
      );
      setState(() => _permission = permission);
    } catch (_) {
      if (mounted) {
        _reportPermissionResult(
          AnalyticsCameraPermissionStatus.failed,
          isSuccess: false,
          failReason: 'permission_check_failed: Camera permission check failed',
        );
        setState(() => _permission = CameraPermissionState.failed);
      }
    } finally {
      _initializing = false;
    }
  }

  /// 调用原生高质量拍照并将临时文件交给流程状态进入预览页。
  Future<void> _takePhoto() async {
    if (!_cameraReady || _capturing) return;
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testPhotoCaptureClick,
        properties: _testFlowProperties(
          AnalyticsPageName.testCapture,
          state.type,
        ),
      ),
    );
    setState(() => _capturing = true);
    try {
      final path = await _camera.capture();
      if (mounted) {
        unawaited(
          ref.report(
            AnalyticsEvent.testPhotoCaptureResult,
            properties: {
              ..._testFlowProperties(AnalyticsPageName.testCapture, state.type),
              AnalyticsEventProperty.isSuccess: 1,
              AnalyticsEventProperty.failReason: '',
            },
          ),
        );
        ref.read(testFlowProvider.notifier).setPhoto(path);
      }
    } catch (_) {
      if (mounted) {
        unawaited(
          ref.report(
            AnalyticsEvent.testPhotoCaptureResult,
            properties: {
              ..._testFlowProperties(AnalyticsPageName.testCapture, state.type),
              AnalyticsEventProperty.isSuccess: 0,
              AnalyticsEventProperty.failReason:
                  'photo_capture_failed: Photo capture failed',
            },
          ),
        );
        setState(() {
          _cameraReady = false;
          _permission = CameraPermissionState.failed;
        });
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _reportPermissionResult(
    AnalyticsCameraPermissionStatus status, {
    required bool isSuccess,
    required String failReason,
  }) {
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testCameraPermissionResult,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testCapture, state.type),
          AnalyticsEventProperty.permissionStatus: status.value,
          AnalyticsEventProperty.isSuccess: isSuccess ? 1 : 0,
          AnalyticsEventProperty.failReason: failReason,
        },
      ),
    );
  }

  void _reportPermissionClick(AnalyticsCameraPermissionAction action) {
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testCameraPermissionClick,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testCapture, state.type),
          AnalyticsEventProperty.action: action.value,
        },
      ),
    );
  }

  void _reportCameraInitResult({required bool isSuccess}) {
    if (_cameraInitResultReported) return;
    _cameraInitResultReported = true;
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testCameraInitResult,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testCapture, state.type),
          AnalyticsEventProperty.isSuccess: isSuccess ? 1 : 0,
          AnalyticsEventProperty.failReason: isSuccess
              ? ''
              : 'camera_init_failed: Camera initialization failed',
        },
      ),
    );
  }

  void _reportCaptureGuideView() {
    if (_guideReported) return;
    _guideReported = true;
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testCaptureGuideView,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testCapture, state.type),
          AnalyticsEventProperty.title: 'Hold steady and align the entire test',
          AnalyticsEventProperty.desc:
              'Place the cassette flat on a plain, dark surface.\nCenter the entire cassette inside the frame.',
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionReady = _permission == CameraPermissionState.ready;
    final canCapture = permissionReady && _cameraReady && !_capturing;
    return ColoredBox(
      color: flowInk,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            children: [
              FlowTopBar(
                title: 'Photo capture',
                onClose: widget.onClose,
                dark: true,
              ),
              if (permissionReady && _cameraReady) ...[
                const SizedBox(height: 24),
                const Text(
                  'Hold steady and align the entire test',
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),
              Expanded(child: _cameraBody()),
              if (permissionReady) ...[
                const SizedBox(height: 16),
                const Text(
                  'Place the cassette flat on a plain, dark surface.\nCenter the entire cassette inside the frame.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: canCapture ? 1 : 0.4,
                  child: GestureDetector(
                    onTap: canCapture ? _takePhoto : null,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraBody() {
    switch (_permission) {
      case CameraPermissionState.loading:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case CameraPermissionState.denied:
        return _PermissionMessage(
          title: 'Camera access is required',
          body: 'Allow camera access to photograph your test cassette.',
          button: 'Allow camera access',
          onPressed: () {
            _reportPermissionClick(AnalyticsCameraPermissionAction.allow);
            return _initialize();
          },
        );
      case CameraPermissionState.permanentlyDenied:
        return _PermissionMessage(
          title: 'Camera access is turned off',
          body: 'Open Settings and allow Nalo to use the camera.',
          button: 'Open Settings',
          onPressed: () async {
            _reportPermissionClick(
              AnalyticsCameraPermissionAction.openSettings,
            );
            await openAppSettings();
          },
        );
      case CameraPermissionState.failed:
        return _PermissionMessage(
          title: 'Camera unavailable',
          body: 'We could not start the camera. Please try again.',
          button: 'Try again',
          onPressed: () {
            _reportPermissionClick(AnalyticsCameraPermissionAction.retry);
            return _initialize();
          },
        );
      case CameraPermissionState.ready:
        // TODO: <pf> 原生成像效果确认后，再决定是否恢复光线、模糊和移动的实时拍照门槛。
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NativeCameraView(
                key: _cameraViewKey,
                controller: _camera,
                onReady: () {
                  if (!mounted) return;
                  _reportCameraInitResult(isSuccess: true);
                  setState(() => _cameraReady = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _reportCaptureGuideView();
                  });
                },
                onError: (_) {
                  if (!mounted) return;
                  _reportCameraInitResult(isSuccess: false);
                  setState(() {
                    _cameraReady = false;
                    _permission = CameraPermissionState.failed;
                  });
                },
              ),
              const ColoredBox(color: Color(0x22000000)),
              const Center(child: _CassetteFrame()),
            ],
          ),
        );
    }
  }
}

/// 相机授权及初始化过程对应的页面展示状态。
enum CameraPermissionState { loading, denied, permanentlyDenied, failed, ready }

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({
    required this.title,
    required this.body,
    required this.button,
    required this.onPressed,
  });
  final String title;
  final String body;
  final String button;
  final Future<void> Function() onPressed;
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white54,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FlowPrimaryButton(label: button, onPressed: onPressed),
        ],
      ),
    ),
  );
}

class _CassetteFrame extends StatelessWidget {
  const _CassetteFrame();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.min(constraints.maxHeight * .50, 340.0);
      final width = height / 3;
      return SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _CassetteFramePainter(),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Position the entire\ntest cassette here',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CassetteFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      border,
    );
    final corner = Paint()
      ..color = flowYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const length = 20.0;
    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, 0)
      ..lineTo(length, 0)
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, length)
      ..moveTo(size.width, size.height - length)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - length, size.height)
      ..moveTo(length, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - length);
    canvas.drawPath(path, corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 展示拍摄结果，由用户选择重拍或上传分析。
class PhotoPreviewScreen extends ConsumerStatefulWidget {
  const PhotoPreviewScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  ConsumerState<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends ConsumerState<PhotoPreviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(testFlowProvider);
      unawaited(
        ref.report(
          AnalyticsEvent.testPhotoPreviewView,
          properties: {
            ..._testFlowProperties(
              AnalyticsPageName.testPhotoPreview,
              state.type,
            ),
            AnalyticsEventProperty.title: 'Photo capture',
            AnalyticsEventProperty.desc:
                'Make sure the entire cassette is visible and clear',
          },
        ),
      );
    });
  }

  void _retake(TestFlowState state) {
    unawaited(
      ref.report(
        AnalyticsEvent.testPhotoRetakeClick,
        properties: {
          ..._testFlowProperties(
            AnalyticsPageName.testPhotoPreview,
            state.type,
          ),
          AnalyticsEventProperty.method:
              AnalyticsPhotoRetakeMethod.retakeButton.value,
        },
      ),
    );
    ref.read(testFlowProvider.notifier).retake();
  }

  void _usePhoto(TestFlowState state) {
    unawaited(
      ref.report(
        AnalyticsEvent.testPhotoUseClick,
        properties: _testFlowProperties(
          AnalyticsPageName.testPhotoPreview,
          state.type,
        ),
      ),
    );
    unawaited(ref.read(testFlowProvider.notifier).analyzePhoto());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFlowProvider);
    final path = state.photoPath;
    return ColoredBox(
      color: flowInk,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              FlowTopBar(
                title: 'Photo capture',
                onBack: widget.onBack,
                dark: true,
              ),
              const SizedBox(height: 24),
              const Text(
                'Make sure the entire cassette is visible and clear',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: path != null
                      ? Image.file(File(path), fit: BoxFit.contain)
                      : const ColoredBox(color: Colors.black26),
                ),
              ),
              const SizedBox(height: 24),
              FlowPrimaryButton(
                label: 'Use this photo',
                yellow: true,
                onPressed:
                    state.isLoading ||
                        state.analysisError ==
                            DetectionAnalysisError.recognitionFailed
                    ? null
                    : () => _usePhoto(state),
              ),
              TextButton.icon(
                onPressed: state.isLoading ? null : () => _retake(state),
                icon: const Icon(Icons.replay, color: Colors.white70, size: 18),
                label: const Text(
                  'Retake',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (state.errorMessage != null)
                Text(
                  state.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF8C7A),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 展示服务端识别区间，并上报用户对区间、日期和检测时段的确认操作。
class ConfirmResultScreen extends ConsumerStatefulWidget {
  const ConfirmResultScreen({required this.onClose, super.key});
  final VoidCallback onClose;

  @override
  ConsumerState<ConfirmResultScreen> createState() =>
      _ConfirmResultScreenState();
}

class _ConfirmResultScreenState extends ConsumerState<ConfirmResultScreen> {
  bool _viewReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportView());
  }

  void _reportView() {
    if (!mounted || _viewReported) return;
    final state = ref.read(testFlowProvider);
    final analysis = state.analysis;
    if (analysis == null) return;
    _viewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultConfirmView,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResultConfirm, state),
          AnalyticsEventProperty.aiValue: analysis.aiValue,
          AnalyticsEventProperty.aiValueResultLevel:
              analysis.aiValueResultLevel,
          AnalyticsEventProperty.detectionTimePeriods:
              analysis.detectionTimePeriod,
          AnalyticsEventProperty.unit: analysis.unit,
          AnalyticsEventProperty.typicalRange: analysis.typicalRange,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFlowProvider);
    final analysis = state.analysis;
    final config = state.effectiveConfig;
    final matchingPeriods = config.timePeriods.options.where(
      (option) => option.value == state.selectedTimePeriod,
    );
    final period = matchingPeriods.isEmpty ? null : matchingPeriods.first;
    return _PaperPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowTopBar(title: state.type.label, onClose: widget.onClose),
          const SizedBox(height: 24),
          const Text(
            'Confirm your result.',
            style: TextStyle(
              color: flowInk,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: flowBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR READING',
                        style: TextStyle(
                          color: Color(0x8CFFFFFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${analysis?.aiValue ?? '—'} ${analysis?.unit ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          height: 40 / 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0x26FFFFFF)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TYPICAL RANGE',
                              style: TextStyle(
                                color: Color(0x80FFFFFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              analysis?.typicalRange ?? '—',
                              style: const TextStyle(
                                color: flowYellow,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (period != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x26FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            period.label,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const FlowSectionLabel('Adjust reading'),
          const SizedBox(height: 10),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FlowSectionLabel(state.readingOptions.title),
                const SizedBox(height: 12),
                for (final option in state.readingOptions.options) ...[
                  FlowChoiceTile(
                    selected: state.selectedLevel == option.value,
                    onTap: () => _selectLevel(
                      state,
                      option.value,
                      state.readingOptions.options.indexOf(option) + 1,
                    ),
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (option != state.readingOptions.options.last)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FlowSectionLabel('Date'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFF5F2EE),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        color: flowBlue,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, state),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 44,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0x14000000)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            state.sampledAt == null
                                ? 'Select date'
                                : DateFormat(
                                    'MM/dd/yyyy',
                                    'en',
                                  ).format(state.sampledAt!),
                            style: const TextStyle(
                              color: flowInk,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FlowSectionLabel(config.timePeriods.title),
                const SizedBox(height: 12),
                for (final option in config.timePeriods.options) ...[
                  FlowChoiceTile(
                    selected: state.selectedTimePeriod == option.value,
                    onTap: () => _selectTimePeriod(
                      state,
                      option.value,
                      config.timePeriods.options.indexOf(option) + 1,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              option.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (option.range.isNotEmpty)
                              Text(
                                option.range,
                                style: const TextStyle(
                                  color: flowMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        if (option.hint.isNotEmpty)
                          Text(
                            option.hint,
                            style: TextStyle(
                              color: state.selectedTimePeriod == option.value
                                  ? Colors.white70
                                  : flowMuted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (option != config.timePeriods.options.last)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          FlowPrimaryButton(
            label: 'Save result',
            onPressed:
                state.selectedLevel == null ||
                    state.selectedTimePeriod == null ||
                    state.isLoading
                ? null
                : () => _saveResult(state),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// 上报用户实际点击的读数区间，再同步当前选择。
  void _selectLevel(TestFlowState state, String value, int position) {
    unawaited(
      ref.report(
        AnalyticsEvent.testResultLevelClick,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResultConfirm, state),
          AnalyticsEventProperty.finalLevel: value,
          AnalyticsEventProperty.position: position,
        },
      ),
    );
    ref.read(testFlowProvider.notifier).selectLevel(value);
  }

  /// 点击日期区域时先上报当前值，日期弹窗取消不撤销点击事件。
  Future<void> _selectDate(BuildContext context, TestFlowState state) async {
    final current = state.sampledAt ?? DateTime.now();
    unawaited(
      ref.report(
        AnalyticsEvent.testResultDateClick,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResultConfirm, state),
          AnalyticsEventProperty.sampledAt: _analyticsDate(current),
        },
      ),
    );
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('en'),
    );
    if (date != null) {
      ref.read(testFlowProvider.notifier).selectSampleDate(date);
    }
  }

  void _selectTimePeriod(TestFlowState state, String value, int position) {
    unawaited(
      ref.report(
        AnalyticsEvent.testResultTimePeriodClick,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResultConfirm, state),
          AnalyticsEventProperty.timePeriod: value,
          AnalyticsEventProperty.position: position,
        },
      ),
    );
    ref.read(testFlowProvider.notifier).selectTimePeriod(value);
  }

  void _saveResult(TestFlowState state) {
    unawaited(
      ref.report(
        AnalyticsEvent.testResultSaveClick,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResultConfirm, state),
          AnalyticsEventProperty.finalLevel: state.selectedLevel ?? '',
          AnalyticsEventProperty.sampledAt: state.sampledAt == null
              ? ''
              : _analyticsDate(state.sampledAt!),
          AnalyticsEventProperty.timePeriod: state.selectedTimePeriod ?? '',
        },
      ),
    );
    unawaited(ref.read(testFlowProvider.notifier).saveResult());
  }
}

/// 第三个同类型检测完成后展示一次庆祝动效。
class MilestoneScreen extends ConsumerStatefulWidget {
  const MilestoneScreen({super.key});
  @override
  ConsumerState<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends ConsumerState<MilestoneScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportView());
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _reportView() {
    if (!mounted) return;
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testCelebrationView,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testCelebration, state),
          AnalyticsEventProperty.title: 'MILESTONE REACHED',
          AnalyticsEventProperty.desc: _celebrationDescription,
        },
      ),
    );
  }

  void _continueToResult() {
    final state = ref.read(testFlowProvider);
    unawaited(
      ref.report(
        AnalyticsEvent.testCelebrationClick,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testCelebration, state),
          AnalyticsEventProperty.action:
              AnalyticsCelebrationAction.keepTesting.value,
        },
      ),
    );
    ref.read(testFlowProvider.notifier).showResult();
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(testFlowProvider.select((state) => state.type));
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: flowInk,
      child: Stack(
        children: [
          for (var index = 0; index < 30; index++)
            _ConfettiPiece(
              index: index,
              animation: reducedMotion
                  ? const AlwaysStoppedAnimation<double>(1)
                  : _animation,
            ),
          Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _animation,
                curve: Curves.easeOut,
              ),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: flowYellow,
                      child: Icon(
                        Icons.emoji_events_outlined,
                        color: flowInk,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'MILESTONE REACHED',
                      style: TextStyle(
                        color: flowBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3 tests\n${type.label}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: flowInk,
                        fontSize: 30,
                        height: 37.5 / 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x12008BC7),
                        border: Border.all(color: const Color(0x26008BC7)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        _celebrationDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF2A6B8A),
                          fontSize: 14,
                          height: 22.75 / 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FlowPrimaryButton(
                      label: 'Keep testing',
                      onPressed: _continueToResult,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPiece extends StatelessWidget {
  const _ConfettiPiece({required this.index, required this.animation});
  final int index;
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final random = math.Random(index * 97);
    final left = random.nextDouble() * size.width;
    final target = random.nextDouble() * size.height;
    final color = [
      flowYellow,
      const Color(0xFFE8553D),
      const Color(0xFF25B5D8),
      Colors.white,
      const Color(0xFF55C99A),
    ][index % 5];
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final delayed = ((animation.value - index % 7 * .045) / .72).clamp(
          0.0,
          1.0,
        );
        return Positioned(
          left: left,
          top: -20 + target * Curves.easeOut.transform(delayed),
          child: Opacity(
            opacity: delayed,
            child: Transform.rotate(
              angle: delayed * math.pi * (1 + index % 4),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: 5 + random.nextDouble() * 6,
        height: 3 + random.nextDouble() * 7,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// 展示最终读数，并统一处理结果内容曝光、Referral 和返回首页事件。
class ResultDetailsScreen extends ConsumerStatefulWidget {
  const ResultDetailsScreen({
    required this.onClose,
    required this.onBackHome,
    super.key,
  });
  final VoidCallback onClose;
  final VoidCallback onBackHome;

  @override
  ConsumerState<ResultDetailsScreen> createState() =>
      _ResultDetailsScreenState();
}

class _ResultDetailsScreenState extends ConsumerState<ResultDetailsScreen> {
  bool _resultViewReported = false;
  bool _infoViewReported = false;
  bool _sectionViewReported = false;
  bool _reminderViewReported = false;
  bool _referralViewReported = false;
  final Set<String> _viewedItems = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportResultView());
  }

  void _reportResultView() {
    if (!mounted || _resultViewReported) return;
    final state = ref.read(testFlowProvider);
    final result = state.result;
    if (result == null) return;
    _resultViewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultView,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResult, state),
          AnalyticsEventProperty.value: result.value ?? '',
          AnalyticsEventProperty.unit: result.unit ?? '',
          AnalyticsEventProperty.testTime: result.testTime ?? '',
          AnalyticsEventProperty.typicalRange: result.typicalRange ?? '',
          AnalyticsEventProperty.infoTitle: result.infoTitle ?? '',
          AnalyticsEventProperty.infoContent: result.infoContent ?? '',
        },
      ),
    );
  }

  void _reportInfoView(
    TestFlowState state,
    String title,
    String desc,
    double visibleFraction,
  ) {
    if (_infoViewReported || visibleFraction < _analyticsVisibleFraction) {
      return;
    }
    _infoViewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultInfoView,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResult, state),
          AnalyticsEventProperty.title: title,
          AnalyticsEventProperty.desc: desc,
        },
      ),
    );
  }

  void _reportSectionView(TestFlowState state, int itemCount, double fraction) {
    if (_sectionViewReported || fraction < _analyticsVisibleFraction) return;
    _sectionViewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultSectionView,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testResult, state.type),
          AnalyticsEventProperty.itemCount: itemCount,
          AnalyticsEventProperty.position: 1,
        },
      ),
    );
  }

  void _reportItemView(
    RecentDetection item,
    DetectionType type,
    int position,
    double fraction,
  ) {
    if (fraction < _analyticsVisibleFraction) return;
    final key = '${_analyticsDetectionType(type).value}:${item.id}';
    if (!_viewedItems.add(key)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultItemView,
        properties: {
          ..._testFlowProperties(AnalyticsPageName.testResult, type),
          AnalyticsEventProperty.testId: item.id.toString(),
          AnalyticsEventProperty.position: position,
          AnalyticsEventProperty.date: item.date,
          AnalyticsEventProperty.timePeriod: item.period,
          AnalyticsEventProperty.value: item.value,
          AnalyticsEventProperty.unit: item.unit,
          AnalyticsEventProperty.typicalRange: item.typicalRange,
        },
      ),
    );
  }

  void _reportReminderView(TestFlowState state, double fraction) {
    if (_reminderViewReported || fraction < _analyticsVisibleFraction) return;
    _reminderViewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.testAgainReminderView,
        properties: {
          ..._testResultProperties(AnalyticsPageName.testResult, state),
          AnalyticsEventProperty.title: 'Test again tomorrow',
          AnalyticsEventProperty.desc: _testAgainDescription,
        },
      ),
    );
  }

  void _reportReferralView(String url, double fraction) {
    if (_referralViewReported || fraction < _analyticsVisibleFraction) return;
    _referralViewReported = true;
    unawaited(
      ref.report(
        AnalyticsEvent.referralView,
        properties: _resultReferralProperties(url),
      ),
    );
  }

  void _shareReferral(String url, String? shareText) {
    unawaited(
      ref.report(
        AnalyticsEvent.referralClick,
        properties: _resultReferralProperties(url),
      ),
    );
    unawaited(_showReferralShare(url, shareText));
  }

  Future<void> _showReferralShare(String url, String? shareText) async {
    try {
      await ref
          .read(platformShareServiceProvider)
          .shareLink(url, message: shareText);
    } on Object {
      if (!mounted) return;
      BotToast.showText(
        text: 'Unable to share referral link',
        align: Alignment.center,
      );
    }
  }

  void _close(TestFlowState state) {
    unawaited(
      ref.report(
        AnalyticsEvent.testFlowExitClick,
        properties: _testFlowProperties(
          AnalyticsPageName.testResult,
          state.type,
        ),
      ),
    );
    widget.onClose();
  }

  void _backHome(TestFlowState state) {
    unawaited(
      ref.report(
        AnalyticsEvent.testResultBackHomeClick,
        properties: _testResultProperties(AnalyticsPageName.testResult, state),
      ),
    );
    widget.onBackHome();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFlowProvider);
    final result = state.result;
    final infoTitle = result?.infoTitle ?? '';
    final infoContent = result?.infoContent ?? '';
    final referralOffer = ref
        .watch(homeDashboardProvider)
        .asData
        ?.value
        .referralOffer;
    return _PaperPage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowTopBar(
            onClose: () => _close(state),
            center: const FlowNaloMark(),
            closeOnRight: true,
          ),
          Text(
            state.type.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: flowMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your result.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: flowInk,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result?.testTime ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: flowMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: flowBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ResultMetric(
                          label: 'YOUR READING',
                          value:
                              '${result?.value ?? '—'} ${result?.unit ?? ''}',
                        ),
                      ),
                      Expanded(
                        child: _ResultMetric(
                          label: 'TYPICAL RANGE',
                          value: result?.typicalRange ?? '—',
                          yellow: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if ((result?.testTime ?? '').isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
                    ),
                    child: Text(
                      '◷  ${result!.testTime}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (infoTitle.isNotEmpty && infoContent.isNotEmpty) ...[
            const SizedBox(height: 24),
            VisibilityDetector(
              key: const ValueKey('test-result-info'),
              onVisibilityChanged: (info) => _reportInfoView(
                state,
                infoTitle,
                infoContent,
                info.visibleFraction,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: flowSoftBlue.withValues(alpha: .3),
                  border: Border.all(color: flowBlue.withValues(alpha: .15)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      infoTitle,
                      style: const TextStyle(
                        color: Color(0xFF216B8F),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      infoContent,
                      style: const TextStyle(
                        color: Color(0xFF347C9C),
                        fontSize: 14,
                        height: 21 / 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          VisibilityDetector(
            key: const ValueKey('test-result-section'),
            onVisibilityChanged: (info) => _reportSectionView(
              state,
              result?.recent.length ?? 0,
              info.visibleFraction,
            ),
            child: FlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FlowSectionLabel(
                    'Last 3 tests · ${state.type.label}',
                    uppercase: false,
                  ),
                  const SizedBox(height: 12),
                  RecentResultsList(
                    items: result?.recent ?? const [],
                    type: state.type,
                    shrinkWrap: true,
                    onItemVisibilityChanged: _reportItemView,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          VisibilityDetector(
            key: const ValueKey('test-again-reminder'),
            onVisibilityChanged: (info) =>
                _reportReminderView(state, info.visibleFraction),
            child: const FlowCard(
              child: Row(
                children: [
                  Icon(Icons.notifications_none, color: flowBlue, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test again tomorrow',
                          style: TextStyle(
                            color: flowInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _testAgainDescription,
                          style: TextStyle(
                            color: flowMuted,
                            fontSize: 12,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (referralOffer != null) ...[
            const SizedBox(height: 20),
            VisibilityDetector(
              key: const ValueKey('test-result-referral'),
              onVisibilityChanged: (info) => _reportReferralView(
                referralOffer.actionUrl,
                info.visibleFraction,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _shareReferral(
                  referralOffer.actionUrl,
                  referralOffer.shareText,
                ),
                child: FlowCard(
                  color: flowYellow,
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard, color: flowInk, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              referralOffer.title,
                              style: const TextStyle(
                                color: flowInk,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              referralOffer.description,
                              style: const TextStyle(
                                color: Color(0xAA1A2433),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              referralOffer.buttonText,
                              style: const TextStyle(
                                color: flowInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FlowPrimaryButton(
            label: 'Back to home',
            onPressed: () => _backHome(state),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    this.yellow = false,
  });
  final String label;
  final String value;
  final bool yellow;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          color: yellow ? flowYellow : Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

Map<AnalyticsEventProperty, Object> _testFlowProperties(
  AnalyticsPageName pageName,
  DetectionType type,
) {
  return {
    AnalyticsEventProperty.pageName: pageName.value,
    AnalyticsEventProperty.detectionType: _analyticsDetectionType(type).value,
  };
}

Map<AnalyticsEventProperty, Object> _testResultProperties(
  AnalyticsPageName pageName,
  TestFlowState state,
) {
  return {
    ..._testFlowProperties(pageName, state.type),
    AnalyticsEventProperty.testId: state.analysis?.id.toString() ?? '',
  };
}

Map<AnalyticsEventProperty, Object> _resultReferralProperties(String url) {
  return {
    AnalyticsEventProperty.pageName: AnalyticsPageName.testResult.value,
    // TODO: <pf> 服务端提供结构化折扣比例后替换固定值 10。
    AnalyticsEventProperty.discountPercent: 10,
    AnalyticsEventProperty.url: url,
  };
}

String _analyticsDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

AnalyticsDetectionType _analyticsDetectionType(DetectionType type) {
  return switch (type) {
    DetectionType.cortisol => AnalyticsDetectionType.cortisol,
    DetectionType.testosterone => AnalyticsDetectionType.testosterone,
  };
}

AnalyticsPageName _timerPageName(TestFlowStep step) {
  return switch (step) {
    TestFlowStep.swab => AnalyticsPageName.testSwab,
    TestFlowStep.dip => AnalyticsPageName.testDip,
    TestFlowStep.develop => AnalyticsPageName.testDevelop,
    _ => throw StateError('The current step is not a timer page.'),
  };
}

int _remainingSeconds(Duration remaining) {
  return (remaining.inMilliseconds / Duration.millisecondsPerSecond).ceil();
}

class _PaperPage extends StatelessWidget {
  const _PaperPage({required this.child, this.scrollable = false});
  final Widget child;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 12,
      20,
      MediaQuery.paddingOf(context).bottom + 40,
    );
    return ColoredBox(
      color: flowPaper,
      child: scrollable
          ? SingleChildScrollView(padding: padding, child: child)
          : Padding(padding: padding, child: child),
    );
  }
}
