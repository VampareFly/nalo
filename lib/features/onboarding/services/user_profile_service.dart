// 封装 Nalo 用户资料查询与更新接口。
// Repository 负责调用时机和页面分流，Service 只处理协议字段。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';

/// 调用用户资料接口并解析服务端响应。
class UserProfileService {
  const UserProfileService(this._apiClient);

  final ApiClient _apiClient;

  /// 获取当前登录用户信息。
  Future<AppUserInfo> getInfo() async {
    final user = await _apiClient.get<AppUserInfo>(
      '/api/v1/app/user/info',
      decoder: _decodeUser,
    );
    if (user == null) {
      throw const ResponseFormatException('The user info response is empty.');
    }
    return user;
  }

  /// 更新资料；非 Shopify用户按需提交 Email，高龄确认后提交 age_confirm。
  Future<AppUserInfo> update({
    required String fullName,
    required DateTime birthDay,
    required int gender,
    String? email,
    bool ageConfirmed = false,
  }) async {
    final user = await _apiClient.post<AppUserInfo>(
      '/api/v1/app/user/update',
      data: {
        'full_name': fullName.trim(),
        'birth_day': _formatDate(birthDay),
        'gender': gender,
        if (email != null) 'email': email.trim(),
        if (ageConfirmed) 'age_confirm': 1,
      },
      decoder: _decodeUser,
    );
    if (user == null) {
      throw const ResponseFormatException(
        'The updated user response is empty.',
      );
    }
    return user;
  }

  AppUserInfo _decodeUser(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException('The user data is not an object.');
    }
    return AppUserInfo.fromJson(data);
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
