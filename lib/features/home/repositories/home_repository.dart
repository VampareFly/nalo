// 为首页 Provider 提供聚合数据入口，不保存页面状态或本地缓存。
// Provider 每次刷新首页时通过本仓库重新请求服务端数据。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/home/models/home_index_data.dart';
import 'package:nalo/features/home/services/home_service.dart';

/// 首页聚合数据仓库。
class HomeRepository {
  const HomeRepository(this._service);

  final HomeService _service;

  /// 获取首页一次渲染所需的远端聚合数据。
  Future<HomeIndexData> fetchIndex() => _service.fetchIndex();
}

/// 提供当前登录业务域可用的首页仓库。
final homeRepositoryProvider = FutureProvider<HomeRepository>((ref) async {
  final client = await ref.watch(businessApiClientProvider.future);
  return HomeRepository(HomeService(client));
});
