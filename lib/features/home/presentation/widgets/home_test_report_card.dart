import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/home/models/home_test_report.dart';
import 'package:tester_kit/features/home/providers/home_test_reports_provider.dart';
import 'package:tester_kit/features/notifications/providers/notification_permission_provider.dart';

class HomeTestReportCard extends ConsumerStatefulWidget {
  const HomeTestReportCard({super.key});

  @override
  ConsumerState<HomeTestReportCard> createState() => _HomeTestReportCardState();
}

class _HomeTestReportCardState extends ConsumerState<HomeTestReportCard> with WidgetsBindingObserver {
  late final PageController _pageController;
  final Map<TestType, int> _pendingStepIndexes = {};
  int _selectedReportIndex = 0;
  bool? _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    unawaited(_refreshNotificationPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotificationPermission());
    }
  }

  Future<void> _refreshNotificationPermission() async {
    final enabled = await ref.read(notificationPermissionServiceProvider).isNotificationPermissionEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
  }

  Future<void> _openNotificationSettings() async {
    // TODO: <pf> Schedule the selected test reminder after notification delivery is implemented.
    await ref.read(notificationPermissionServiceProvider).openAppSettings();
  }

  void _showPendingStep(HomeTestReport report, int index) {
    setState(() => _pendingStepIndexes[report.type] = index);
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(homeTestReportsProvider);

    return Container(
      height: 510,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: reports.length,
              onPageChanged: (index) => setState(() => _selectedReportIndex = index),
              itemBuilder: (context, index) {
                final report = reports[index];
                final pendingIndex = _pendingStepIndexes[report.type] ?? 0;
                return _ReportPage(
                  report: report,
                  pendingIndex: pendingIndex,
                  showRemindButton: _notificationsEnabled == false,
                  onPendingStepChanged: (stepIndex) => _showPendingStep(report, stepIndex),
                  onRemindPressed: _openNotificationSettings,
                );
              },
            ),
          ),
          _TypeSelector(
            reports: reports,
            selectedIndex: _selectedReportIndex,
            onSelected: (index) => _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportPage extends StatelessWidget {
  const _ReportPage({
    required this.report,
    required this.pendingIndex,
    required this.showRemindButton,
    required this.onPendingStepChanged,
    required this.onRemindPressed,
  });

  final HomeTestReport report;
  final int pendingIndex;
  final bool showRemindButton;
  final ValueChanged<int> onPendingStepChanged;
  final VoidCallback onRemindPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.dateLabel,
            style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, height: 1, fontWeight: FontWeight.w500, letterSpacing: 1.4),
          ),
          const SizedBox(height: 20),
          _TestProgress(completedSteps: report.completedSteps, totalSteps: report.totalSteps),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(report.result, style: const TextStyle(color: Color(0xFF050505), fontSize: 42, height: 0.9, fontWeight: FontWeight.w700)),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(report.unit, style: const TextStyle(color: Color(0xFF77777A), fontSize: 14, height: 1)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBDF2CE)),
                ),
                child: Text(
                  report.rangeStatus,
                  style: const TextStyle(color: Color(0xFF269C57), fontSize: 11, height: 1, fontWeight: FontWeight.w500, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _RangeBar(markerPosition: report.markerPosition),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: Text(report.lowRange, style: _rangeLabelStyle)),
              Expanded(child: Text(report.normalRange, textAlign: TextAlign.center, style: _rangeLabelStyle)),
              Expanded(child: Text(report.highRange, textAlign: TextAlign.end, style: _rangeLabelStyle)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PendingStepPanel(
                report: report,
                pendingIndex: pendingIndex,
                showRemindButton: showRemindButton,
                onPendingStepChanged: onPendingStepChanged,
                onRemindPressed: onRemindPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _rangeLabelStyle = TextStyle(color: Color(0xFF77777A), fontSize: 9, height: 1, letterSpacing: 0.5);

class _TestProgress extends StatelessWidget {
  const _TestProgress({required this.completedSteps, required this.totalSteps});

  final int completedSteps;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < totalSteps; index++) ...[
          _ProgressNode(step: index + 1, isComplete: index < completedSteps),
          if (index < totalSteps - 1)
            Container(
              width: 31,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              color: index < completedSteps - 1 ? const Color(0xFF050505) : const Color(0xFFE6E6E6),
            ),
        ],
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Test $completedSteps of $totalSteps',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF77777A), fontSize: 11, height: 1, letterSpacing: 0.6),
          ),
        ),
      ],
    );
  }
}

class _ProgressNode extends StatelessWidget {
  const _ProgressNode({required this.step, required this.isComplete});

  final int step;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: isComplete ? const Color(0xFF050505) : const Color(0xFFE5E5E5), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: isComplete
          ? const Icon(Icons.check, color: Colors.white, size: 13)
          : Text('$step', style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.markerPosition});

  final double markerPosition;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const markerWidth = 60.0;
          final markerLeft = (constraints.maxWidth * markerPosition - markerWidth / 2)
              .clamp(0.0, constraints.maxWidth - markerWidth)
              .toDouble();
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const Row(
                  children: [
                    Expanded(flex: 1, child: ColoredBox(color: Color(0xFF80C5FF), child: SizedBox(height: 11))),
                    Expanded(flex: 5, child: ColoredBox(color: Color(0xFF82EBAA), child: SizedBox(height: 11))),
                    Expanded(flex: 3, child: ColoredBox(color: Color(0xFFFFA3A7), child: SizedBox(height: 11))),
                  ],
                ),
              ),
              Positioned(
                left: markerLeft,
                child: Container(
                  width: markerWidth,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF050505),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PendingStepPanel extends StatelessWidget {
  const _PendingStepPanel({
    required this.report,
    required this.pendingIndex,
    required this.showRemindButton,
    required this.onPendingStepChanged,
    required this.onRemindPressed,
  });

  final HomeTestReport report;
  final int pendingIndex;
  final bool showRemindButton;
  final ValueChanged<int> onPendingStepChanged;
  final VoidCallback onRemindPressed;

  @override
  Widget build(BuildContext context) {
    final pendingSteps = report.pendingSteps;
    if (pendingSteps.isEmpty) {
      return const _CompletedPanel();
    }

    final safePendingIndex = pendingIndex.clamp(0, pendingSteps.length - 1).toInt();
    final step = pendingSteps[safePendingIndex];
    final canGoBack = pendingSteps.length > 1 && pendingIndex > 0;
    final canGoForward = pendingSteps.length > 1 && pendingIndex < pendingSteps.length - 1;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFE9E9E9)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pendingSteps.length} more ${pendingSteps.length == 1 ? 'reading' : 'readings'} to unlock your full report.',
                  style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, height: 1.3, letterSpacing: 0.6),
                ),
                const SizedBox(height: 15),
                Text(step.eyebrow, style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, height: 1, letterSpacing: 1.4)),
                const SizedBox(height: 10),
                Text(
                  step.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF202023), fontSize: 15, height: 1.15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                Text(
                  step.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF77777A), fontSize: 11, height: 1.35, letterSpacing: 0.4),
                ),
                const Spacer(),
                if (showRemindButton)
                  OutlinedButton.icon(
                    onPressed: onRemindPressed,
                    icon: const Icon(Icons.notifications_none, size: 15),
                    label: const Text('Remind me'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF91A5F1),
                      side: const BorderSide(color: Color(0xFFAEC0FF)),
                      minimumSize: const Size(0, 35),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (canGoBack) Positioned(left: -13, top: 0, child: _StepArrow(icon: Icons.chevron_left, onPressed: () => onPendingStepChanged(pendingIndex - 1))),
        if (canGoForward) Positioned(right: -13, top: 0, child: _StepArrow(icon: Icons.chevron_right, onPressed: () => onPendingStepChanged(pendingIndex + 1))),
      ],
    );
  }
}

class _CompletedPanel extends StatelessWidget {
  const _CompletedPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REPORT COMPLETE', style: TextStyle(color: Color(0xFF77777A), fontSize: 10, letterSpacing: 1.4)),
          SizedBox(height: 10),
          Text('Your full report is ready', style: TextStyle(color: Color(0xFF202023), fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: CircleBorder(side: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(width: 30, height: 30, child: Icon(icon, color: const Color(0xFF202023), size: 18)),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.reports, required this.selectedIndex, required this.onSelected});

  final List<HomeTestReport> reports;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFECECEC)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TypeButton(report: reports[0], isSelected: selectedIndex == 0, onPressed: () => onSelected(0)),
          const SizedBox(width: 8),
          for (var index = 0; index < reports.length; index++) ...[
            _PageIndicator(isSelected: selectedIndex == index),
            if (index < reports.length - 1) const SizedBox(width: 6),
          ],
          const SizedBox(width: 8),
          _TypeButton(report: reports[1], isSelected: selectedIndex == 1, onPressed: () => onSelected(1)),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.report, required this.isSelected, required this.onPressed});

  final HomeTestReport report;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isSelected ? null : onPressed,
      style: TextButton.styleFrom(
        disabledForegroundColor: const Color(0xFF77777A),
        foregroundColor: const Color(0xFFDADADA),
        overlayColor: Colors.transparent,
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.7),
      ),
      child: Text(report.label),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isSelected ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF050505) : const Color(0xFFA9B5F4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
