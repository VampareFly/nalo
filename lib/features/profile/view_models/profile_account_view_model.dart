// 管理 Profile 页的退出登录和账号注销状态。
// Widget 只处理确认弹窗、Toast 和导航，会话生命周期交由 AuthSessionNotifier 编排。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';

/// Profile 账号操作的页面状态。
class ProfileAccountState {
  const ProfileAccountState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;
}

/// 防止重复提交并将账号操作错误转换为页面反馈。
class ProfileAccountViewModel extends Notifier<ProfileAccountState> {
  @override
  ProfileAccountState build() => const ProfileAccountState();

  /// 直接退出登录；服务端失败不阻止本地退出。
  Future<bool> logout() async {
    if (state.isLoading) return false;
    state = const ProfileAccountState(isLoading: true);
    try {
      await ref.read(authSessionProvider.notifier).logout();
    } catch (_) {
      // 退出登录以用户本地意图为准，不因服务端或分析异常阻止导航。
    } finally {
      state = const ProfileAccountState();
    }
    return true;
  }

  /// 用户确认后请求服务端注销，只在成功时结束本地会话。
  Future<bool> deactivate() async {
    if (state.isLoading) return false;
    state = const ProfileAccountState(isLoading: true);
    try {
      await ref.read(authSessionProvider.notifier).deactivate();
      state = const ProfileAccountState();
      return true;
    } on ApiException catch (error) {
      state = ProfileAccountState(errorMessage: error.message);
    } on SessionExpiredException catch (error) {
      state = ProfileAccountState(errorMessage: error.message);
    } on NetworkException catch (error) {
      state = ProfileAccountState(errorMessage: error.message);
    } on ResponseFormatException catch (error) {
      state = ProfileAccountState(errorMessage: error.message);
    } catch (_) {
      state = const ProfileAccountState(
        errorMessage: 'Unable to delete your account. Please try again.',
      );
    }
    return false;
  }
}

/// 提供 Profile 页账号操作状态。
final profileAccountViewModelProvider =
    NotifierProvider.autoDispose<ProfileAccountViewModel, ProfileAccountState>(
      ProfileAccountViewModel.new,
    );
