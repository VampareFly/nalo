// 管理首页与检测流程共享的最近三次结果内存缓存。
// 首页刷新和结果接口成功时写入，检测流程按类型读取并区分未加载与空结果。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';

/// 单个检测类型的最近结果缓存条目。
class RecentTestsCacheEntry {
  const RecentTestsCacheEntry({required this.items});

  final List<RecentDetection> items;
}

/// 两种检测类型在当前 App 进程内的共享缓存状态。
class RecentTestsCacheState {
  const RecentTestsCacheState({this.entries = const {}});

  final Map<DetectionType, RecentTestsCacheEntry> entries;

  /// 判断指定类型是否已经从任一接口成功加载，包括结果为空的情况。
  bool hasLoaded(DetectionType type) => entries.containsKey(type);

  /// 返回指定类型的最近结果，未加载和空结果都返回空列表。
  List<RecentDetection> itemsFor(DetectionType type) =>
      entries[type]?.items ?? const [];
}

/// 接收首页和检测流程数据并更新共享最近结果缓存。
class RecentTestsCacheController extends Notifier<RecentTestsCacheState> {
  final Map<DetectionType, Future<List<RecentDetection>>> _pendingLoads = {};
  int _generation = 0;

  @override
  RecentTestsCacheState build() {
    ref.listen(authSessionProvider, (_, next) {
      final status = next.value?.status;
      if (status == AuthSessionStatus.unauthenticated ||
          status == AuthSessionStatus.sessionExpired) {
        clear();
      }
    });
    return const RecentTestsCacheState();
  }

  /// 覆盖一个检测类型的最近结果，并将该类型标记为已加载。
  void replace(DetectionType type, List<RecentDetection> items) {
    state = RecentTestsCacheState(
      entries: Map.unmodifiable({
        ...state.entries,
        type: RecentTestsCacheEntry(items: List.unmodifiable(items)),
      }),
    );
  }

  /// 仅在指定类型尚未加载时执行请求，并复用同类型正在进行的请求。
  Future<List<RecentDetection>> loadIfNeeded(
    DetectionType type,
    Future<List<RecentDetection>> Function() loader,
  ) {
    if (state.hasLoaded(type)) return Future.value(state.itemsFor(type));
    final pending = _pendingLoads[type];
    if (pending != null) return pending;
    late final Future<List<RecentDetection>> operation;
    operation = _performLoad(type, _generation, loader).whenComplete(() {
      if (identical(_pendingLoads[type], operation)) {
        _pendingLoads.remove(type);
      }
    });
    _pendingLoads[type] = operation;
    return operation;
  }

  Future<List<RecentDetection>> _performLoad(
    DetectionType type,
    int generation,
    Future<List<RecentDetection>> Function() loader,
  ) async {
    final items = await loader();
    if (generation != _generation) return const [];
    if (state.hasLoaded(type)) return state.itemsFor(type);
    replace(type, items);
    return state.itemsFor(type);
  }

  /// 首页聚合接口成功后同时覆盖两种检测类型，缺失类型按已加载空结果处理。
  void replaceFromHome({
    required List<RecentDetection> cortisol,
    required List<RecentDetection> testosterone,
  }) {
    state = RecentTestsCacheState(
      entries: Map.unmodifiable({
        DetectionType.cortisol: RecentTestsCacheEntry(
          items: List.unmodifiable(cortisol),
        ),
        DetectionType.testosterone: RecentTestsCacheEntry(
          items: List.unmodifiable(testosterone),
        ),
      }),
    );
  }

  /// 会话退出或失效时清空缓存，避免最近结果跨账号保留。
  void clear() {
    _generation++;
    _pendingLoads.clear();
    state = const RecentTestsCacheState();
  }
}

/// 提供首页与检测流程共享、随 App 进程保留的最近结果缓存。
final recentTestsCacheProvider =
    NotifierProvider<RecentTestsCacheController, RecentTestsCacheState>(
      RecentTestsCacheController.new,
    );
