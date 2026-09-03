// 编排用户资料接口并隔离 ViewModel 与网络 Service。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/onboarding/services/user_profile_service.dart';

/// 提供用户资料查询和更新能力。
class UserProfileRepository {
  const UserProfileRepository(this._service, this._currentUserStorage);

  final UserProfileService _service;
  final CurrentUserStorage _currentUserStorage;

  /// 获取当前用户资料，并用服务端最新响应覆盖本地快照。
  Future<AppUserInfo> getInfo() async {
    final user = await _service.getInfo();
    await _saveSnapshot(user);
    return user;
  }

  /// 更新资料并透传可选高龄确认，成功后保存服务端最新用户。
  Future<AppUserInfo> update({
    required String fullName,
    required DateTime birthDay,
    required int gender,
    bool ageConfirmed = false,
  }) async {
    final user = await _service.update(
      fullName: fullName,
      birthDay: birthDay,
      gender: gender,
      ageConfirmed: ageConfirmed,
    );
    await _saveSnapshot(user);
    return user;
  }

  Future<void> _saveSnapshot(AppUserInfo user) async {
    try {
      await _currentUserStorage.save(user);
    } catch (_) {
      // TODO: <pf> 明确用户快照写入失败时的产品处理方式。
    }
  }
}

/// 注入用户资料 Repository。
final userProfileRepositoryProvider = FutureProvider<UserProfileRepository>((
  ref,
) async {
  final apiClient = await ref.watch(businessApiClientProvider.future);
  return UserProfileRepository(
    UserProfileService(apiClient),
    await ref.watch(currentUserStorageProvider.future),
  );
});
