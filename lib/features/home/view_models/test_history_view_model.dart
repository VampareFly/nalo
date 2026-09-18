// 管理检测历史的首次加载、服务端筛选、分页合并与错误恢复。
// 页面每次进入主动加载第一页，离开后 autoDispose 释放本次浏览状态。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/home/models/test_history_models.dart';
import 'package:nalo/features/home/repositories/test_history_repository.dart';

/// 检测历史页面状态。
class TestHistoryState {
  const TestHistoryState({
    this.filter = TestHistoryFilter.all,
    this.counts = const TestHistoryCounts.empty(),
    this.groups = const [],
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.nextEndDate = '',
    this.initialError,
    this.loadMoreError = false,
  });

  final TestHistoryFilter filter;
  final TestHistoryCounts counts;
  final List<TestHistoryGroup> groups;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final String nextEndDate;
  final Object? initialError;
  final bool loadMoreError;

  /// 当前筛选下没有历史结果。
  bool get isEmpty => !isInitialLoading && initialError == null && groups.isEmpty;

  /// 创建字段更新后的页面状态。
  TestHistoryState copyWith({
    TestHistoryFilter? filter,
    TestHistoryCounts? counts,
    List<TestHistoryGroup>? groups,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextEndDate,
    Object? initialError,
    bool clearInitialError = false,
    bool? loadMoreError,
  }) => TestHistoryState(
    filter: filter ?? this.filter,
    counts: counts ?? this.counts,
    groups: groups ?? this.groups,
    isInitialLoading: isInitialLoading ?? this.isInitialLoading,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    nextEndDate: nextEndDate ?? this.nextEndDate,
    initialError: clearInitialError ? null : initialError ?? this.initialError,
    loadMoreError: loadMoreError ?? this.loadMoreError,
  );
}

/// 编排检测历史请求并避免筛选切换时的旧请求覆盖新状态。
class TestHistoryViewModel extends Notifier<TestHistoryState> {
  int _requestGeneration = 0;
  final Map<TestHistoryFilter, TestHistoryState> _filterCache = {};

  @override
  TestHistoryState build() => const TestHistoryState();

  /// 每次进入页面或重试时重新请求当前筛选的第一页。
  Future<void> loadInitial() => _loadFirstPage(state.filter);

  /// 下拉刷新当前筛选并保留现有内容，由 RefreshIndicator 单独展示刷新进度。
  Future<void> refresh() {
    if (state.isRefreshing || state.isInitialLoading || state.isLoadingMore) {
      return Future.value();
    }
    return _loadFirstPage(state.filter, preserveContent: true);
  }

  /// 切换筛选时优先恢复当前页面周期内的缓存，未加载时请求第一页。
  Future<void> selectFilter(TestHistoryFilter filter) async {
    if (filter == state.filter && state.initialError == null) return;
    final cached = _filterCache[filter];
    if (cached != null) {
      _requestGeneration++;
      state = cached;
      return;
    }
    await _loadFirstPage(filter);
  }

  Future<void> _loadFirstPage(
    TestHistoryFilter filter, {
    bool preserveContent = false,
  }) async {
    final generation = ++_requestGeneration;
    final previous = state;
    final existingCounts = state.counts;
    if (preserveContent) {
      state = state.copyWith(isRefreshing: true);
    } else {
      state = TestHistoryState(
        filter: filter,
        counts: existingCounts,
        isInitialLoading: true,
      );
    }
    try {
      final repository = await ref.read(testHistoryRepositoryProvider.future);
      final page = await repository.fetch(filter: filter);
      if (generation != _requestGeneration) return;
      final updated = TestHistoryState(
        filter: filter,
        counts: page.counts,
        groups: page.groups,
        hasMore: page.hasMore,
        nextEndDate: page.nextEndDate,
      );
      _filterCache[filter] = updated;
      state = updated;
    } catch (error) {
      if (generation != _requestGeneration) return;
      state = preserveContent
          ? previous.copyWith(isRefreshing: false)
          : TestHistoryState(filter: filter, initialError: error);
    }
  }

  /// 列表接近底部时加载下一页，同一时间只允许一个分页请求。
  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isRefreshing || state.isLoadingMore || !state.hasMore || state.nextEndDate.isEmpty) return;
    final generation = _requestGeneration;
    state = state.copyWith(isLoadingMore: true, loadMoreError: false);
    try {
      final repository = await ref.read(testHistoryRepositoryProvider.future);
      final page = await repository.fetch(filter: state.filter, endDate: state.nextEndDate);
      if (generation != _requestGeneration) return;
      final updated = state.copyWith(
        groups: _mergeGroups(state.groups, page.groups),
        isLoadingMore: false,
        hasMore: page.hasMore,
        nextEndDate: page.nextEndDate,
        loadMoreError: false,
      );
      _filterCache[state.filter] = updated;
      state = updated;
    } catch (_) {
      if (generation != _requestGeneration) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: true);
    }
  }
}

List<TestHistoryGroup> _mergeGroups(List<TestHistoryGroup> current, List<TestHistoryGroup> incoming) {
  final merged = [...current];
  for (final group in incoming) {
    final index = merged.indexWhere((item) => item.sortKey == group.sortKey);
    if (index == -1) {
      merged.add(group);
    } else {
      merged[index] = merged[index].copyWith(items: [...merged[index].items, ...group.items]);
    }
  }
  return List.unmodifiable(merged);
}

/// 提供单次历史页面浏览周期内的状态和操作。
final testHistoryViewModelProvider = NotifierProvider.autoDispose<TestHistoryViewModel, TestHistoryState>(
  TestHistoryViewModel.new,
);
