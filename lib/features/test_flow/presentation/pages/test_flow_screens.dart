// 检测流程页面集合：按 Provider 状态渲染说明、计时、拍照、确认、庆祝和结果页面。
import 'dart:io';
import 'dart:math' as math;

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';
import 'package:nalo/features/test_flow/presentation/widgets/native_camera_view.dart';
import 'package:nalo/features/test_flow/presentation/widgets/test_flow_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _openReferralLink(String link) async {
  final uri = Uri.tryParse(link);
  final didOpen =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!didOpen) {
    BotToast.showText(
      text: 'Unable to open referral link',
      align: Alignment.center,
    );
  }
}

/// 展示检测类型选择、注意事项和最近三次结果。
class AboutTestScreen extends ConsumerWidget {
  const AboutTestScreen({required this.onClose, super.key});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testFlowProvider);
    return _PaperPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowTopBar(onClose: onClose, center: const FlowNaloMark()),
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
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeButton(
                  type: DetectionType.testosterone,
                  selected: state.type == DetectionType.testosterone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FlowSectionLabel('Last 3 tests'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: RecentResultsList(
                      items: state.recent,
                      type: state.type,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FlowPrimaryButton(
            label: 'Start test',
            onPressed: ref.read(testFlowProvider.notifier).showBeforeStart,
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends ConsumerWidget {
  const _TypeButton({required this.type, required this.selected});
  final DetectionType type;
  final bool selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: 48,
    child: OutlinedButton(
      onPressed: () => ref.read(testFlowProvider.notifier).selectType(type),
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
  const RecentResultsList({required this.items, required this.type, super.key});
  final List<RecentDetection> items;
  final DetectionType type;
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
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = items[index];
        return Container(
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
      },
    );
  }
}

/// 展示正式检测开始前的准备要求。
class BeforeStartScreen extends ConsumerWidget {
  const BeforeStartScreen({required this.onBack, super.key});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _PaperPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlowTopBar(onBack: onBack),
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
        const _PreparationCard(
          icon: Icons.schedule,
          iconColor: flowBlue,
          title: 'No eating, drinking or brushing',
          body: 'for 30 minutes before the test.',
        ),
        const SizedBox(height: 16),
        const _PreparationCard(
          icon: Icons.notifications_none,
          iconColor: Color(0xFFF5A623),
          title: 'Test at the same time',
          body:
              'For the most consistent results, test at the same time of day each time.',
        ),
        const Spacer(),
        FlowPrimaryButton(
          label: "Ready, let's go",
          onPressed: ref.read(testFlowProvider.notifier).beginSwab,
        ),
      ],
    ),
  );
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
                      ? controller.resumeTimer
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
              onPressed: controller.nextAfterTimer,
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
    if (warning) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const _RiskDialog(
          title: 'Pause timer?',
          body: 'The strip will continue developing while the timer is paused.',
          confirm: 'Pause',
        ),
      );
      if (confirmed != true) return;
    }
    ref.read(testFlowProvider.notifier).pauseTimer();
  }

  /// 显色阶段跳过前要求用户确认已实际等待满十五分钟。
  Future<void> _skip(BuildContext context, WidgetRef ref, bool warning) async {
    if (warning) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const _RiskDialog(
          title: 'Skip timer?',
          body:
              'Only continue if the strip has already developed for the full 15 minutes.',
          confirm: 'Continue',
        ),
      );
      if (confirmed != true) return;
    }
    ref.read(testFlowProvider.notifier).skipTimer();
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
      setState(() => _permission = permission);
    } catch (_) {
      if (mounted) setState(() => _permission = CameraPermissionState.failed);
    } finally {
      _initializing = false;
    }
  }

  /// 调用原生高质量拍照并将临时文件交给流程状态进入预览页。
  Future<void> _takePhoto() async {
    if (!_cameraReady || _capturing) return;
    setState(() => _capturing = true);
    try {
      final path = await _camera.capture();
      if (mounted) ref.read(testFlowProvider.notifier).setPhoto(path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _cameraReady = false;
          _permission = CameraPermissionState.failed;
        });
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
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
          onPressed: _initialize,
        );
      case CameraPermissionState.permanentlyDenied:
        return _PermissionMessage(
          title: 'Camera access is turned off',
          body: 'Open Settings and allow Nalo to use the camera.',
          button: 'Open Settings',
          onPressed: () async {
            await openAppSettings();
          },
        );
      case CameraPermissionState.failed:
        return _PermissionMessage(
          title: 'Camera unavailable',
          body: 'We could not start the camera. Please try again.',
          button: 'Try again',
          onPressed: _initialize,
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
                  if (mounted) setState(() => _cameraReady = true);
                },
                onError: (_) {
                  if (!mounted) return;
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
class PhotoPreviewScreen extends ConsumerWidget {
  const PhotoPreviewScreen({required this.onBack, super.key});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testFlowProvider);
    final path = state.photoPath;
    return ColoredBox(
      color: flowInk,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              FlowTopBar(title: 'Photo capture', onBack: onBack, dark: true),
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
                    : ref.read(testFlowProvider.notifier).analyzePhoto,
              ),
              TextButton.icon(
                onPressed: state.isLoading
                    ? null
                    : ref.read(testFlowProvider.notifier).retake,
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

/// 展示服务端识别区间，并允许用户修正区间、日期和检测时段。
class ConfirmResultScreen extends ConsumerWidget {
  const ConfirmResultScreen({required this.onClose, super.key});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testFlowProvider);
    final controller = ref.read(testFlowProvider.notifier);
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
          FlowTopBar(title: state.type.label, onClose: onClose),
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
                    onTap: () => controller.selectLevel(option.value),
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
                        onTap: () => _selectDate(context, ref),
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
                    onTap: () => controller.selectTimePeriod(option.value),
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
                : controller.saveResult,
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

  /// 仅选择年月日，并强制日期选择器使用英文区域格式。
  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(testFlowProvider).sampledAt ?? DateTime.now();
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
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
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
                        'Consistent testing is everything. Each result builds a clearer picture of your hormone patterns over time. Keep going — your data is working for you.',
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
                      onPressed: ref.read(testFlowProvider.notifier).showResult,
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

/// 展示服务端返回的最终读数、正常区间、说明和最近三次记录。
class ResultDetailsScreen extends ConsumerWidget {
  const ResultDetailsScreen({required this.onClose, super.key});
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onClose: onClose,
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
            Container(
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
          ],
          const SizedBox(height: 24),
          FlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FlowSectionLabel(
                  'Last 3 tests · ${state.type.label}',
                  uppercase: false,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: math
                      .max(72, (result?.recent.length ?? 0) * 72)
                      .toDouble(),
                  child: RecentResultsList(
                    items: result?.recent ?? const [],
                    type: state.type,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const FlowCard(
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
                        'Patterns build over time. The more you test, the clearer the picture.',
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
          if (referralOffer != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openReferralLink(referralOffer.actionUrl),
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
          ],
          const SizedBox(height: 24),
          FlowPrimaryButton(label: 'Back to home', onPressed: onClose),
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
