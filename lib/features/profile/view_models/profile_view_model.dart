// 管理 Profile 用户资料的本地快照和服务端刷新。
// 页面进入时先展示本地数据，再通过 user/info 刷新并覆盖当前快照。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/onboarding/repositories/user_profile_repository.dart';

/// Profile 主页面的数据状态。
class ProfileState {
  const ProfileState({this.user, this.isLoading = false, this.errorMessage});

  final AppUserInfo? user;
  final bool isLoading;
  final String? errorMessage;
}

/// 读取本地用户并在页面进入时请求服务端最新资料。
class ProfileViewModel extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState();

  /// 首次进入或从编辑页返回时刷新 Profile 数据。
  Future<void> load() async {
    if (state.isLoading) return;
    final storage = await ref.read(currentUserStorageProvider.future);
    final localUser = state.user ?? await storage.read();
    state = ProfileState(user: localUser, isLoading: true);
    try {
      final repository = await ref.read(userProfileRepositoryProvider.future);
      final user = await repository.getInfo();
      state = ProfileState(user: user);
    } on ApiException catch (error) {
      state = ProfileState(user: localUser, errorMessage: error.message);
    } on SessionExpiredException catch (error) {
      state = ProfileState(user: localUser, errorMessage: error.message);
    } on NetworkException catch (error) {
      state = ProfileState(user: localUser, errorMessage: error.message);
    } on ResponseFormatException catch (error) {
      state = ProfileState(user: localUser, errorMessage: error.message);
    } catch (_) {
      state = ProfileState(
        user: localUser,
        errorMessage: 'Unable to load your profile. Please try again.',
      );
    }
  }

  /// 编辑成功后立即用 update 响应刷新 Profile，不追加 user/info 请求。
  void useUpdatedUser(AppUserInfo user) {
    state = ProfileState(user: user);
  }
}

/// 提供跨 Profile 与 Edit profile 路由共享的用户资料状态。
final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileState>(ProfileViewModel.new);
