// 检测流程入口：根据 Provider 状态切换页面，并统一处理返回、退出确认和全局 Loading。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(testFlowProvider.notifier).initialize(),
    );
  }

  @override
  void dispose() {
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
              TestFlowStep.about => AboutTestScreen(
                onClose: _exitWithoutPrompt,
              ),
              TestFlowStep.beforeStart => BeforeStartScreen(
                onBack: () => _setStep(TestFlowStep.about),
              ),
              TestFlowStep.swab ||
              TestFlowStep.dip ||
              TestFlowStep.develop => TestTimerScreen(
                onBack: ref.read(testFlowProvider.notifier).previousTimerStep,
                onExit: _confirmExit,
              ),
              TestFlowStep.capture => CaptureScreen(onClose: _confirmExit),
              TestFlowStep.preview => PhotoPreviewScreen(
                onBack: ref.read(testFlowProvider.notifier).retake,
              ),
              TestFlowStep.confirm => ConfirmResultScreen(
                onClose: _confirmExit,
              ),
              TestFlowStep.milestone => const MilestoneScreen(),
              TestFlowStep.result => ResultDetailsScreen(
                onClose: _exitAfterCompletion,
              ),
            },
            if (state.isLoading) const _GlobalLoading(),
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
        _exitWithoutPrompt();
        return;
      case TestFlowStep.beforeStart:
        _setStep(TestFlowStep.about);
        return;
      case TestFlowStep.swab:
      case TestFlowStep.dip:
      case TestFlowStep.develop:
        ref.read(testFlowProvider.notifier).previousTimerStep();
        return;
      case TestFlowStep.preview:
        ref.read(testFlowProvider.notifier).retake();
        return;
      case TestFlowStep.confirm:
        _confirmExit();
        return;
      case TestFlowStep.result:
        _exitAfterCompletion();
        return;
      default:
        _confirmExit();
        return;
    }
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
  Future<void> _confirmExit() async {
    if (ref.read(testFlowProvider).isLoading) return;
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
    if (shouldExit == true && mounted) _exitWithoutPrompt();
  }

  void _exitWithoutPrompt() {
    ref.read(testFlowProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  void _exitAfterCompletion() {
    ref.read(testFlowProvider.notifier).reset();
    Navigator.of(context).pop();
  }
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

class _GlobalLoading extends StatelessWidget {
  const _GlobalLoading();
  @override
  Widget build(BuildContext context) => const AbsorbPointer(
    child: ColoredBox(
      color: Color(0x99000000),
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
    ),
  );
}
