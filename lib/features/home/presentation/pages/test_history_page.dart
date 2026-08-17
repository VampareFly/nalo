// 展示用户完整检测历史，并支持按检测类型筛选和按月份分组。
// 页面暂时复用首页聚合 Provider；服务端历史接口确定后切换到独立 Repository。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';

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

enum _HistoryFilter { all, cortisol, testosterone }

class _TestHistoryPageState extends ConsumerState<TestHistoryPage> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(homeDashboardProvider);
    return Scaffold(
      backgroundColor: _historyBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _HistoryAppBar(),
            Expanded(
              child: dashboard.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _historyBlue)),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(homeDashboardProvider),
                    child: const Text('Try again'),
                  ),
                ),
                data: (data) => _HistoryBody(
                  data: data,
                  selectedFilter: _filter,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
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

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.data, required this.selectedFilter, required this.onFilterChanged});

  final HomeDashboardData data;
  final _HistoryFilter selectedFilter;
  final ValueChanged<_HistoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final allResults = [...data.testosteroneResults, ...data.cortisolResults];
    final filtered = switch (selectedFilter) {
      _HistoryFilter.all => allResults,
      _HistoryFilter.cortisol => data.cortisolResults,
      _HistoryFilter.testosterone => data.testosteroneResults,
    };
    final grouped = <String, List<HomeRecentResult>>{};
    for (final result in filtered) {
      grouped.putIfAbsent(result.monthLabel, () => []).add(result);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Row(
          children: [
            Expanded(child: _FilterButton(label: 'All', count: allResults.length, selected: selectedFilter == _HistoryFilter.all, onTap: () => onFilterChanged(_HistoryFilter.all))),
            const SizedBox(width: 8),
            Expanded(child: _FilterButton(label: 'Cortisol', count: data.cortisolResults.length, selected: selectedFilter == _HistoryFilter.cortisol, onTap: () => onFilterChanged(_HistoryFilter.cortisol))),
            const SizedBox(width: 8),
            Expanded(child: _FilterButton(label: 'Testosterone', count: data.testosteroneResults.length, selected: selectedFilter == _HistoryFilter.testosterone, onTap: () => onFilterChanged(_HistoryFilter.testosterone))),
          ],
        ),
        const SizedBox(height: 12),
        Text(_resultSummary(filtered.length), style: const TextStyle(color: _historyMuted, fontSize: 12)),
        const SizedBox(height: 18),
        for (final entry in grouped.entries) ...[
          _MonthHeader(label: entry.key, count: entry.value.length),
          const SizedBox(height: 12),
          for (var index = 0; index < entry.value.length; index++) ...[
            _HistoryResultRow(result: entry.value[index]),
            if (index < entry.value.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  String _resultSummary(int count) {
    final type = switch (selectedFilter) {
      _HistoryFilter.all => '',
      _HistoryFilter.cortisol => ' · Cortisol',
      _HistoryFilter.testosterone => ' · Testosterone',
    };
    return '$count ${count == 1 ? 'result' : 'results'}$type';
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
  final HomeRecentResult result;

  @override
  Widget build(BuildContext context) {
    final accent = result.type == HomeTestType.cortisol ? const Color(0xFF8AB4CB) : const Color(0xFFF5C842);
    final typeLabel = result.type == HomeTestType.cortisol ? 'Cortisol' : 'Testosterone';
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
                Text(result.dateLabel, style: const TextStyle(color: _historyInk, fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${result.periodLabel}   ·   $typeLabel', style: const TextStyle(color: _historyMuted, fontSize: 12)),
              ],
            ),
          ),
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
