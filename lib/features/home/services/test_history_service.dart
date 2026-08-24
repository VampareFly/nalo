// 封装检测历史 HTTP 请求，只负责参数组装与响应解码。
// Repository 通过本服务获取指定筛选条件下的一页历史数据。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/home/models/test_history_models.dart';

/// 检测历史接口服务。
class TestHistoryService {
  const TestHistoryService(this._client);

  final ApiClient _client;

  /// 获取指定类型的一页检测历史；endDate 仅在加载下一页时传入。
  Future<TestHistoryPageData> fetch({
    required TestHistoryFilter filter,
    String? endDate,
  }) async {
    final result = await _client.get<TestHistoryPageData>(
      '/api/v1/app/detections/history',
      queryParameters: {
        'detection_type': filter.apiValue,
        if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      },
      decoder: TestHistoryPageData.fromJson,
    );
    if (result == null) {
      throw const ResponseFormatException('Test history data is empty.');
    }
    return result;
  }
}
