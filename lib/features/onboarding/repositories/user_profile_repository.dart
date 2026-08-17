// 编排用户资料接口并隔离 ViewModel 与网络 Service。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/onboarding/services/user_profile_service.dart';

/// 提供用户资料查询和更新能力。
class UserProfileRepository {
  const UserProfileRepository(this._service);

  final UserProfileService _service;

  /// 获取当前登录用户资料。
  Future<AppUserInfo> getInfo() => _service.getInfo();

  /// 提交注册资料并返回服务端最新用户信息。
  Future<AppUserInfo> update({
    required String fullName,
    required DateTime birthDay,
    required int gender,
  }) async {
    return _service.update(
      fullName: fullName,
      birthDay: birthDay,
      gender: gender,
    );
  }
}

/// 注入用户资料 Repository。
final userProfileRepositoryProvider = FutureProvider<UserProfileRepository>((
  ref,
) async {
  final apiClient = await ref.watch(businessApiClientProvider.future);
  return UserProfileRepository(UserProfileService(apiClient));
});
