import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';

class TestFlowPage extends ConsumerStatefulWidget {
  const TestFlowPage({super.key});

  static const path = '/test';

  @override
  ConsumerState<TestFlowPage> createState() => _TestFlowPageState();
}

class _TestFlowPageState extends ConsumerState<TestFlowPage> with WidgetsBindingObserver {
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _next() => setState(() => _pageIndex++);

  void _backToCapture() => setState(() => _pageIndex = 5);

  Future<void> _close() async {
    final shouldExit = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _ExitTestSheet(),
    );

    if (shouldExit == true && mounted) {
      ref.read(testFlowProvider.notifier).reset();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _BeforeStartPage(onNext: _next),
      _TimedStepPage(key: const ValueKey('test-step-1'), step: 1, title: 'Swab your gums', seconds: 20, instruction: 'Move swab along upper gum line', onNext: _next),
      _TimedStepPage(key: const ValueKey('test-step-2'), step: 2, title: 'Swirl in the tube', seconds: 10, instruction: 'Swirl the swab 5 times in the liquid', onNext: _next),
      _DropSamplePage(onNext: _next),
      _TimedStepPage(key: const ValueKey('test-step-4'), step: 4, title: 'Wait for the T lines', seconds: 60, instruction: "Don't touch the strip", onNext: _next),
      _CapturePage(onNext: _next),
      _ImageCheckPage(onContinue: _next, onRetake: _backToCapture),
      const _ConfirmResultPage(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F5F2),
        body: SafeArea(
          child: Column(
            children: [
              _FlowHeader(label: _headerLabel, onClose: _close),
              Expanded(child: pages[_pageIndex]),
            ],
          ),
        ),
      ),
    );
  }

  String get _headerLabel => switch (_pageIndex) {
    0 => 'New test',
    >= 1 && <= 4 => 'Step $_pageIndex of 4',
    5 => 'Scan strip',
    6 => 'Checking image',
    _ => 'Confirm result',
  };
}

class _ExitTestSheet extends StatelessWidget {
  const _ExitTestSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCDCDCD), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Exit this test?', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, fontSize: 28)),
            const SizedBox(height: 10),
            const Text('Your progress will not be saved.', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: Color(0xFF747474))),
            const SizedBox(height: 28),
            _PrimaryButton(label: 'Continue test', onPressed: () => Navigator.pop(context, false)),
            const SizedBox(height: 12),
            _SecondaryButton(label: 'Exit test', onPressed: () => Navigator.pop(context, true)),
          ],
        ),
      ),
      ),
    );
  }
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({required this.label, required this.onClose});

  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: Color(0xFFE2E2E2))),
            child: IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Color(0xFF656565), size: 28)),
          ),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: Color(0xFF6B6B6B), letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

class _BeforeStartPage extends ConsumerWidget {
  const _BeforeStartPage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(testFlowProvider.select((state) => state.testType));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('Before you start'),
          const SizedBox(height: 14),
          const Text(
            'For best results test within 1 hour of waking. Avoid eating or drinking 30 minutes before.',
            style: TextStyle(fontSize: 18, height: 1.45, color: Color(0xFF747474)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(radius: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TEST TYPE', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF747474), letterSpacing: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SelectionButton(
                        label: 'Cortisol',
                        selected: selectedType == TestType.cortisol,
                        onPressed: () => ref.read(testFlowProvider.notifier).selectTestType(TestType.cortisol),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SelectionButton(
                        label: 'Testosterone',
                        selected: selectedType == TestType.testosterone,
                        onPressed: () => ref.read(testFlowProvider.notifier).selectTestType(TestType.testosterone),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _OverviewRow(number: 1, label: 'Swab · your gums', detail: '20 sec'),
          const SizedBox(height: 10),
          const _OverviewRow(number: 2, label: 'Mix · in the tube', detail: '10 sec'),
          const SizedBox(height: 10),
          const _OverviewRow(number: 3, label: 'Test · drip onto strip', detail: '3 drops'),
          const SizedBox(height: 10),
          const _OverviewRow(number: 4, label: 'Results', detail: '60 sec'),
          const SizedBox(height: 40),
          _PrimaryButton(label: 'Start test', onPressed: onNext),
        ],
      ),
    );
  }
}

class _SelectionButton extends StatelessWidget {
  const _SelectionButton({required this.label, required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Colors.black : Colors.white,
          foregroundColor: selected ? Colors.white : const Color(0xFF666666),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17),
        ),
        child: Text(label),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.number, required this.label, required this.detail});

  final int number;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _cardDecoration(radius: 20, shadow: false),
      child: Row(
        children: [
          CircleAvatar(radius: 17, backgroundColor: const Color(0xFFA6B4F3), child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 17))),
          Text(detail, style: const TextStyle(fontFamily: 'monospace', fontSize: 15, color: Color(0xFF707070))),
        ],
      ),
    );
  }
}

class _TimedStepPage extends StatefulWidget {
  const _TimedStepPage({required this.step, required this.title, required this.seconds, required this.instruction, required this.onNext, required ValueKey<String> key});

  final int step;
  final String title;
  final int seconds;
  final String instruction;
  final VoidCallback onNext;

  @override
  State<_TimedStepPage> createState() => _TimedStepPageState();
}

class _TimedStepPageState extends State<_TimedStepPage> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _endsAt;
  late int _remaining = widget.seconds;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _TimedStepPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step || oldWidget.seconds != widget.seconds) {
      _timer?.cancel();
      _timer = null;
      _endsAt = null;
      _remaining = widget.seconds;
      _started = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncRemaining();
  }

  void _start() {
    _endsAt = DateTime.now().add(Duration(seconds: widget.seconds));
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _syncRemaining());
  }

  void _syncRemaining() {
    final endsAt = _endsAt;
    if (endsAt == null || !mounted) return;
    final milliseconds = endsAt.difference(DateTime.now()).inMilliseconds;
    final nextRemaining = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    if (nextRemaining != _remaining) setState(() => _remaining = nextRemaining);
    if (nextRemaining == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete = _started && _remaining == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(widget.title),
          const Spacer(),
          Center(
            child: SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: _started ? _remaining / widget.seconds : 1,
                      strokeWidth: 12,
                      color: const Color(0xFFA8B7F4),
                      backgroundColor: const Color(0xFFE4E7F3),
                    ),
                  ),
                  Text(
                    '$_remaining',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF676767),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(widget.instruction, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 30),
          _PrimaryButton(
            label: complete ? 'Next' : 'Start',
            onPressed: complete ? widget.onNext : (_started ? null : _start),
          ),
        ],
      ),
    );
  }
}

class _DropSamplePage extends StatelessWidget {
  const _DropSamplePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('Drip 3 drops · wait for the C line'),
          const SizedBox(height: 14),
          const Text("Squeeze the dropper and release 3 drops onto the strip's sample well. Wait for the liquid to absorb fully.", style: TextStyle(fontSize: 18, height: 1.4, color: Color(0xFF747474))),
          const Spacer(),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [Text('💧', style: TextStyle(fontSize: 74)), Text('💧', style: TextStyle(fontSize: 74)), Text('💧', style: TextStyle(fontSize: 74))],
          ),
          const Spacer(),
          _PrimaryButton(label: 'Done — I see the C line', onPressed: onNext),
        ],
      ),
    );
  }
}

class _CapturePage extends ConsumerWidget {
  const _CapturePage({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('Record the T lines'),
          const SizedBox(height: 10),
          const Text("Position the strip in the frame. Make sure it's flat and well-lit.", style: TextStyle(fontSize: 17, height: 1.35, color: Color(0xFF747474))),
          const SizedBox(height: 20),
          const Expanded(child: _CameraPlaceholder()),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: 'Capture',
            onPressed: () {
              // TODO: <pf> Replace the placeholder with CameraController capture and pass the image to the quality-check service.
              ref.read(testFlowProvider.notifier).recordCapture(DateTime.now());
              onNext();
            },
          ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(32)),
      child: const Stack(
        children: [
          Positioned(top: 20, left: 20, child: _FrameCorner()),
          Positioned(top: 20, right: 20, child: RotatedBox(quarterTurns: 1, child: _FrameCorner())),
          Positioned(bottom: 20, right: 20, child: RotatedBox(quarterTurns: 2, child: _FrameCorner())),
          Positioned(bottom: 20, left: 20, child: RotatedBox(quarterTurns: 3, child: _FrameCorner())),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.photo_camera_outlined, color: Color(0xFF777777), size: 48), SizedBox(height: 12), Text('Position strip here', style: TextStyle(color: Color(0xFF777777), fontSize: 18))])),
        ],
      ),
    );
  }
}

class _FrameCorner extends StatelessWidget {
  const _FrameCorner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(painter: _FrameCornerPainter()),
    );
  }
}

class _FrameCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF929292)..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..moveTo(0, size.height)..lineTo(0, 0)..lineTo(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ImageCheckPage extends StatelessWidget {
  const _ImageCheckPage({required this.onContinue, required this.onRetake});

  final VoidCallback onContinue;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('AI checking for image quality'),
          const SizedBox(height: 28),
          const _QualityRow(icon: '💡', label: 'Lighting'),
          const SizedBox(height: 16),
          const _QualityRow(icon: '📐', label: 'Angle'),
          const SizedBox(height: 16),
          const _QualityRow(icon: '🧪', label: 'Sample quality'),
          const Spacer(),
          // TODO: <pf> Replace the static successful result with the image-quality service response.
          _PrimaryButton(label: 'Looks good — continue', onPressed: onContinue),
          const SizedBox(height: 12),
          _SecondaryButton(label: 'Retake', onPressed: onRetake),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: _cardDecoration(radius: 28),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 25)),
          const SizedBox(width: 18),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600))),
          const Text('✓ Good', style: TextStyle(fontSize: 18, color: Color(0xFF18A957), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ConfirmResultPage extends ConsumerStatefulWidget {
  const _ConfirmResultPage();

  @override
  ConsumerState<_ConfirmResultPage> createState() => _ConfirmResultPageState();
}

class _ConfirmResultPageState extends ConsumerState<_ConfirmResultPage> {
  DateTime? _selectedAt;

  Future<void> _selectDateTime() async {
    final initial = _selectedAt ?? ref.read(testFlowProvider).capturedAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('en'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('en'),
        child: child,
      ),
    );
    if (time == null) return;
    setState(() => _selectedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testFlowProvider);
    final capturedAt = _selectedAt ?? state.capturedAt;
    final valueLabel = state.testType == TestType.cortisol ? 'CORTISOL VALUE (NG/ML)' : 'TESTOSTERONE VALUE';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('Confirm your result'),
          const SizedBox(height: 12),
          const Text('Review the detected value and confirm when the test was taken.', style: TextStyle(fontSize: 18, height: 1.4, color: Color(0xFF747474))),
          const SizedBox(height: 26),
          Text(valueLabel, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF747474), letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3E3E3))),
            child: Row(
              children: [
                Text(state.detectedValue.toStringAsFixed(1), style: const TextStyle(fontFamily: 'monospace', fontSize: 30, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Text(state.testType == TestType.cortisol ? 'ng/mL' : '', style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: Color(0xFF6E6E6E))),
                const Spacer(),
                const Text('AI DETECTED', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF747474), letterSpacing: 1.2)),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text('TEST DATE & TIME', style: TextStyle(fontFamily: 'monospace', color: Color(0xFF747474), letterSpacing: 1.5)),
          const SizedBox(height: 10),
          _DateTimeField(value: capturedAt, onPressed: _selectDateTime),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFFFF8D9), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8C628))),
            child: const Text('⏱️  Record the actual test time as accurately as possible. Hormone levels change throughout the day, and an inaccurate time may make your trend data misleading.', style: TextStyle(fontSize: 16, height: 1.45)),
          ),
          const SizedBox(height: 26),
          // TODO: <pf> Persist the confirmed result after the result repository is defined.
          _PrimaryButton(label: 'See my result', onPressed: capturedAt == null ? null : () {}),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.value, required this.onPressed});

  final DateTime? value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = value == null ? 'Select date & time' : DateFormat('MM/dd/yyyy, h:mm a', 'en').format(value!);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4E4E4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, color: value == null ? const Color(0xFF747474) : Colors.black),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today_outlined, size: 22, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontFamily: 'serif', fontStyle: FontStyle.italic, fontSize: 30, height: 1.2, color: Colors.black));
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(backgroundColor: Colors.black, disabledBackgroundColor: const Color(0xFFBDBDBD), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
        child: Text(label),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.black, backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFFE1E1E1)), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 19)),
        child: Text(label),
      ),
    );
  }
}

BoxDecoration _cardDecoration({required double radius, bool shadow = true}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadow ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8))] : null,
  );
}
