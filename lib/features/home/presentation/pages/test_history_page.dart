// 展示用户完整检测历史，支持服务端筛选、按月份分组与滚动分页。
// 页面负责筛选、空状态检测入口及 Section、Item 曝光；检测流程返回后刷新记录。
// 单次页面访问周期内按稳定业务键去重。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/app/navigation/test_flow_entry_coordinator.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/widgets/nalo_back_button.dart';
import 'package:nalo/core/widgets/nalo_state_view.dart';
import 'package:nalo/features/home/models/test_history_models.dart';
import 'package:nalo/features/home/view_models/test_history_view_model.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _historyBlue = Color(0xFF008BC7);
const _historyInk = Color(0xFF1A2433);
const _historyMuted = Color(0xFF9FA89E);
const _historyBackground = Color(0xFFEDE8E0);
const _visibleFraction = 0.1;

/// 用户完整检测历史页面。
class TestHistoryPage extends ConsumerStatefulWidget {
  const TestHistoryPage({super.key});

  static const path = '/test-history';

  @override
  ConsumerState<TestHistoryPage> createState() => _TestHistoryPageState();
}

class _TestHistoryPageState extends ConsumerState<TestHistoryPage> {
  final _scrollController = ScrollController();
  bool _loadMoreArmed = true;
  final Set<String> _viewedSections = {};
  final Set<String> _viewedItems = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        ref.read(testHistoryViewModelProvider.notifier).loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreWhenNeeded() {
    final position = _scrollController.position;
    if (!_loadMoreArmed ||
        position.extentAfter >= 240 ||
        position.userScrollDirection != ScrollDirection.reverse) {
      return;
    }
    final state = ref.read(testHistoryViewModelProvider);
    if (state.isInitialLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.nextEndDate.isEmpty) {
      return;
    }
    _loadMoreArmed = false;
    unawaited(ref.read(testHistoryViewModelProvider.notifier).loadMore());
  }

  void _selectFilter(TestHistoryState state, TestHistoryFilter filter) {
    unawaited(
      ref.report(
        AnalyticsEvent.testHistoryFilterClick,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.testHistory.value,
          AnalyticsEventProperty.detectionType: _analyticsDetectionType(
            filter,
          ).value,
          AnalyticsEventProperty.itemCount: state.counts.forFilter(filter),
        },
      ),
    );
    unawaited(
      ref.read(testHistoryViewModelProvider.notifier).selectFilter(filter),
    );
  }

  Future<void> _startTestFromEmptyState() async {
    await ref
        .read(testFlowEntryCoordinatorProvider)
        .open(
          source: AnalyticsTestFlowSource.testHistoryEmpty,
          pageName: AnalyticsPageName.testHistory,
          position: AnalyticsTestStartPosition.testHistoryEmpty,
          totalTestCount: 0,
        );
    if (!mounted) return;
    await ref.read(testHistoryViewModelProvider.notifier).loadInitial();
  }

  void _reportSectionView(
    TestHistoryGroup group,
    int position,
    double visibleFraction,
  ) {
    if (visibleFraction < _visibleFraction) return;
    final detectionType = _groupDetectionType(group);
    final key =
        '${AnalyticsPageName.testHistory.value}:${detectionType.value}:${group.monthLabel}';
    if (!_viewedSections.add(key)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultSectionView,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.testHistory.value,
          AnalyticsEventProperty.detectionType: detectionType.value,
          AnalyticsEventProperty.itemCount: group.items.length,
          AnalyticsEventProperty.date: group.monthLabel,
          AnalyticsEventProperty.position: position,
        },
      ),
    );
  }

  void _reportItemView(
    TestHistoryItem item,
    int position,
    double visibleFraction,
  ) {
    if (visibleFraction < _visibleFraction) return;
    final detectionType = _analyticsDetectionType(item.type);
    final testId = item.id.toString();
    final key =
        '${AnalyticsPageName.testHistory.value}:${detectionType.value}:$testId';
    if (!_viewedItems.add(key)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultItemView,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.testHistory.value,
          AnalyticsEventProperty.testId: testId,
          AnalyticsEventProperty.detectionType: detectionType.value,
          AnalyticsEventProperty.position: position,
          AnalyticsEventProperty.date: item.date,
          AnalyticsEventProperty.timePeriod: item.timePeriod,
          AnalyticsEventProperty.value: item.value,
          AnalyticsEventProperty.unit: item.unit,
          AnalyticsEventProperty.typicalRange: item.typicalRange,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testHistoryViewModelProvider);
    return Scaffold(
      backgroundColor: _historyBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _HistoryAppBar(),
            Expanded(
              child: RefreshIndicator(
                color: _historyBlue,
                notificationPredicate: (notification) =>
                    !state.isLoadingMore && notification.depth == 0,
                onRefresh: () =>
                    ref.read(testHistoryViewModelProvider.notifier).refresh(),
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (notification) {
                    if (notification.dragDetails != null) {
                      _loadMoreArmed = true;
                    }
                    return false;
                  },
                  child: ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      _FilterRow(
                        state: state,
                        onSelected: (filter) => _selectFilter(state, filter),
                      ),
                      const SizedBox(height: 12),
                      _HistoryContent(
                        state: state,
                        onStartTest: _startTestFromEmptyState,
                        onViewAll: () =>
                            _selectFilter(state, TestHistoryFilter.all),
                        onSectionVisibilityChanged: _reportSectionView,
                        onItemVisibilityChanged: _reportItemView,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryAppBar extends StatelessWidget {
  const _HistoryAppBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0F000000))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            'Test history',
            style: TextStyle(
              color: _historyInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Transform.translate(
              offset: const Offset(-6, 0),
              child: NaloBackButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: SvgPicture.asset(
                  'assets/icons/history_back.svg',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.state, required this.onSelected});

  final TestHistoryState state;
  final ValueChanged<TestHistoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (
          var index = 0;
          index < TestHistoryFilter.values.length;
          index++
        ) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _FilterButton(
              label: TestHistoryFilter.values[index].label,
              count: state.counts.forFilter(TestHistoryFilter.values[index]),
              selected: state.filter == TestHistoryFilter.values[index],
              onTap: () => onSelected(TestHistoryFilter.values[index]),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryContent extends ConsumerWidget {
  const _HistoryContent({
    required this.state,
    required this.onStartTest,
    required this.onViewAll,
    required this.onSectionVisibilityChanged,
    required this.onItemVisibilityChanged,
  });

  final TestHistoryState state;
  final VoidCallback onStartTest;
  final VoidCallback onViewAll;
  final void Function(
    TestHistoryGroup group,
    int position,
    double visibleFraction,
  )
  onSectionVisibilityChanged;
  final void Function(
    TestHistoryItem item,
    int position,
    double visibleFraction,
  )
  onItemVisibilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isInitialLoading) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator(color: _historyBlue)),
      );
    }
    if (state.initialError != null) {
      return NaloStateView(
        illustrationAsset: NaloStateIllustration.networkError,
        title: 'We couldn\'t connect',
        description: 'Check your internet connection and try again.',
        actionLabel: 'Try again',
        onAction: () =>
            ref.read(testHistoryViewModelProvider.notifier).loadInitial(),
      );
    }

    final count = state.counts.forFilter(state.filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _resultSummary(count, state.filter),
          style: const TextStyle(color: _historyMuted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        if (state.isEmpty)
          state.counts.all == 0
              ? NaloStateView(
                  illustrationAsset: NaloStateIllustration.testHistoryEmpty,
                  title: 'No test results yet',
                  description:
                      'Complete your first test to start tracking your hormone results.',
                  actionLabel: 'Start a test',
                  onAction: onStartTest,
                  usePrimaryAction: true,
                )
              : NaloStateView(
                  illustrationAsset: NaloStateIllustration.testHistoryEmpty,
                  title: 'No matching results',
                  description: 'There are no results for this test type yet.',
                  actionLabel: 'View all results',
                  onAction: onViewAll,
                )
        else
          for (
            var groupIndex = 0;
            groupIndex < state.groups.length;
            groupIndex++
          )
            _HistoryMonthSection(
              group: state.groups[groupIndex],
              position: groupIndex + 1,
              onSectionVisibilityChanged: onSectionVisibilityChanged,
              onItemVisibilityChanged: onItemVisibilityChanged,
            ),
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  color: _historyBlue,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        if (state.loadMoreError)
          Center(
            child: TextButton(
              onPressed: () =>
                  ref.read(testHistoryViewModelProvider.notifier).loadMore(),
              child: const Text('Try loading more'),
            ),
          ),
      ],
    );
  }
}

class _HistoryMonthSection extends StatelessWidget {
  const _HistoryMonthSection({
    required this.group,
    required this.position,
    required this.onSectionVisibilityChanged,
    required this.onItemVisibilityChanged,
  });

  final TestHistoryGroup group;
  final int position;
  final void Function(
    TestHistoryGroup group,
    int position,
    double visibleFraction,
  )
  onSectionVisibilityChanged;
  final void Function(
    TestHistoryItem item,
    int position,
    double visibleFraction,
  )
  onItemVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VisibilityDetector(
          key: ValueKey('history-section-${group.sortKey}'),
          onVisibilityChanged: (info) =>
              onSectionVisibilityChanged(group, position, info.visibleFraction),
          child: _MonthHeader(
            label: group.monthLabel,
            count: group.items.length,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < group.items.length; index++) ...[
          VisibilityDetector(
            key: ValueKey('history-item-${group.items[index].id}'),
            onVisibilityChanged: (info) => onItemVisibilityChanged(
              group.items[index],
              index + 1,
              info.visibleFraction,
            ),
            child: _HistoryResultRow(result: group.items[index]),
          ),
          if (index < group.items.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : _historyBlue;
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: foreground,
          backgroundColor: selected ? _historyBlue : Colors.white,
          side: const BorderSide(color: _historyBlue, width: 1.5),
          shape: const StadiumBorder(),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.white24 : const Color(0x1A008BC7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _historyInk,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0x1A008BC7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _historyBlue,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryResultRow extends StatelessWidget {
  const _HistoryResultRow({required this.result});

  final TestHistoryItem result;

  @override
  Widget build(BuildContext context) {
    final accent = result.type == TestHistoryFilter.cortisol
        ? const Color(0xFF8AB4CB)
        : const Color(0xFFF5C842);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F2EE),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.date,
                  style: const TextStyle(
                    color: _historyInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${result.timePeriod}   ·   ${result.type.label}',
                  style: const TextStyle(color: _historyMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.valueLabel,
                style: const TextStyle(
                  color: _historyInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Typical range',
                style: TextStyle(color: _historyMuted, fontSize: 10),
              ),
              Text(
                result.typicalRange,
                style: const TextStyle(
                  color: Color(0xFFB07D00),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _resultSummary(int count, TestHistoryFilter filter) {
  final type = filter == TestHistoryFilter.all ? '' : ' · ${filter.label}';
  return '$count ${count == 1 ? 'result' : 'results'}$type';
}

AnalyticsDetectionType _analyticsDetectionType(TestHistoryFilter filter) {
  return switch (filter) {
    TestHistoryFilter.cortisol => AnalyticsDetectionType.cortisol,
    TestHistoryFilter.testosterone => AnalyticsDetectionType.testosterone,
    TestHistoryFilter.all => AnalyticsDetectionType.unknown,
  };
}

AnalyticsDetectionType _groupDetectionType(TestHistoryGroup group) {
  if (group.items.isEmpty) return AnalyticsDetectionType.unknown;
  final firstType = group.items.first.type;
  if (group.items.any((item) => item.type != firstType)) {
    return AnalyticsDetectionType.unknown;
  }
  return _analyticsDetectionType(firstType);
}
