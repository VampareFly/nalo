// 调用公开版本检查接口并解析更新配置。
// 请求上下文由 Repository 从当前应用和设备环境中获取。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/app_update/models/app_version_update.dart';

/// 封装版本检查网络请求。
class AppVersionService {
  const AppVersionService(this._apiClient);

  final ApiClient _apiClient;

  /// 检查当前版本在指定设备与平台上是否需要更新。
  Future<AppVersionUpdate> checkVersion({
    required String currentVersion,
    required String platform,
    required String deviceId,
    required String language,
  }) async {
    final result = await _apiClient.get<AppVersionUpdate>(
      '/api/v1/app/configs/version/check',
      queryParameters: {
        'current_version': currentVersion,
        'platform': platform,
        'device_id': deviceId,
        'lang': language,
      },
      requiresAuth: false,
      decoder: (data) {
        if (data is! Map<String, dynamic>) {
          throw const ResponseFormatException(
            'The version-check data is not an object.',
          );
        }
        return AppVersionUpdate.fromJson(data);
      },
    );
    if (result == null) {
      throw const ResponseFormatException(
        'The version-check response data is empty.',
      );
    }
    return result;
  }
}
