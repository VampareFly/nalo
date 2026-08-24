// 封装首页聚合 HTTP 请求，只负责请求和响应解码。
// Repository 通过本服务获取一次首页展示所需的全部远端数据。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/home/models/home_index_data.dart';

/// 首页聚合接口服务。
class HomeService {
  const HomeService(this._client);

  final ApiClient _client;

  /// 获取首页问候语、检测总数和最近检测结果。
  Future<HomeIndexData> fetchIndex() async {
    final result = await _client.get<HomeIndexData>(
      '/api/v1/app/index',
      decoder: HomeIndexData.fromJson,
    );
    if (result == null) {
      throw const ResponseFormatException('Home index data is empty.');
    }
    return result;
  }
}
