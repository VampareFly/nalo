// 为检测历史 ViewModel 提供稳定的数据入口。
// Repository 不保存页面状态，分页与筛选生命周期由 ViewModel 管理。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/home/models/test_history_models.dart';
import 'package:nalo/features/home/services/test_history_service.dart';

/// 检测历史数据仓库。
class TestHistoryRepository {
  const TestHistoryRepository(this._service);

  final TestHistoryService _service;

  /// 获取指定筛选条件下的一页检测历史。
  Future<TestHistoryPageData> fetch({
    required TestHistoryFilter filter,
    String? endDate,
  }) => _service.fetch(filter: filter, endDate: endDate);
}

/// 提供当前登录业务域可用的检测历史仓库。
final testHistoryRepositoryProvider = FutureProvider<TestHistoryRepository>((ref) async {
  final client = await ref.watch(businessApiClientProvider.future);
  return TestHistoryRepository(TestHistoryService(client));
});
