// 展示用户完整检测历史，支持服务端筛选、按月份分组与滚动分页。
// 页面进入时由 ViewModel 请求第一页，行项目当前仅展示、不响应点击。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nalo/features/home/models/test_history_models.dart';
import 'package:nalo/features/home/view_models/test_history_view_model.dart';

const _historyBlue = Color(0xFF008BC7);
const _historyInk = Color(0xFF1A2433);
const _historyMuted = Color(0xFF9FA89E);
const _historyBackground = Color(0xFFEDE8E0);

/// 用户完整检测历史页面。
class TestHistoryPage extends ConsumerStatefulWidget {
  const TestHistoryPage({super.key});

  static const path = '/test-history';

  @override
  ConsumerState<TestHistoryPage> createState() => _TestHistoryPageState();
}

class _TestHistoryPageState extends ConsumerState<TestHistoryPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(testHistoryViewModelProvider.notifier).loadInitial();
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
    if (_scrollController.position.extentAfter < 240) {
      ref.read(testHistoryViewModelProvider.notifier).loadMore();
    }
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
                onRefresh: () => ref
                    .read(testHistoryViewModelProvider.notifier)
                    .refresh(),
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    _FilterRow(state: state),
                    const SizedBox(height: 12),
                    _HistoryContent(state: state),
                  ],
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x0F000000)))),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text('Test history', style: TextStyle(color: _historyInk, fontSize: 16, fontWeight: FontWeight.w800)),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: SvgPicture.asset('assets/icons/history_back.svg', width: 24, height: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.state});

  final TestHistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (var index = 0; index < TestHistoryFilter.values.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _FilterButton(
              label: TestHistoryFilter.values[index].label,
              count: state.counts.forFilter(TestHistoryFilter.values[index]),
              selected: state.filter == TestHistoryFilter.values[index],
              onTap: () => ref.read(testHistoryViewModelProvider.notifier).selectFilter(TestHistoryFilter.values[index]),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryContent extends ConsumerWidget {
  const _HistoryContent({required this.state});

  final TestHistoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isInitialLoading) {
      return const SizedBox(height: 260, child: Center(child: CircularProgressIndicator(color: _historyBlue)));
    }
    if (state.initialError != null) {
      return _MessageState(
        title: 'Unable to load test history',
        actionLabel: 'Try again',
        onAction: () => ref.read(testHistoryViewModelProvider.notifier).loadInitial(),
      );
    }

    final count = state.counts.forFilter(state.filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_resultSummary(count, state.filter), style: const TextStyle(color: _historyMuted, fontSize: 12)),
        const SizedBox(height: 18),
        if (state.isEmpty)
          const _MessageState(title: 'No test results yet.')
        else
          for (final group in state.groups) ...[
            _MonthHeader(label: group.monthLabel, count: group.items.length),
            const SizedBox(height: 12),
            for (var index = 0; index < group.items.length; index++) ...[
              _HistoryResultRow(result: group.items[index]),
              if (index < group.items.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 24),
          ],
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(color: _historyBlue, strokeWidth: 2))),
          ),
        if (state.loadMoreError)
          Center(
            child: TextButton(
              onPressed: () => ref.read(testHistoryViewModelProvider.notifier).loadMore(),
              child: const Text('Try loading more'),
            ),
          ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _historyMuted, fontSize: 14)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, required this.count, required this.selected, required this.onTap});

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
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: selected ? Colors.white24 : const Color(0x1A008BC7), borderRadius: BorderRadius.circular(20)),
                child: Text('$count', style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800)),
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
        Text(label, style: const TextStyle(color: _historyInk, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0x1A008BC7), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: const TextStyle(color: _historyBlue, fontSize: 10, fontWeight: FontWeight.w800)),
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
    final accent = result.type == TestHistoryFilter.cortisol ? const Color(0xFF8AB4CB) : const Color(0xFFF5C842);
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
                Text(result.date, style: const TextStyle(color: _historyInk, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${result.timePeriod}   ·   ${result.type.label}', style: const TextStyle(color: _historyMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(result.valueLabel, style: const TextStyle(color: _historyInk, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text('Typical range', style: TextStyle(color: _historyMuted, fontSize: 10)),
              Text(result.typicalRange, style: const TextStyle(color: Color(0xFFB07D00), fontSize: 10, fontWeight: FontWeight.w700)),
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
