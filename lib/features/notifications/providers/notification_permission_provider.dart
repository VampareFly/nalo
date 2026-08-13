import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/storage/shared_preferences_provider.dart';
import 'package:nalo/features/notifications/repositories/notification_permission_repository.dart';
import 'package:nalo/features/notifications/services/notification_permission_service.dart';

/// 注入系统通知权限 Service。
final notificationPermissionServiceProvider = Provider<NotificationPermissionService>((ref) {
  return PlatformNotificationPermissionService();
});

/// 注入通知权限首次请求配置 Repository。
final notificationPermissionRepositoryProvider =
    FutureProvider<NotificationPermissionRepository>((ref) async {
      final preferences = await ref.watch(sharedPreferencesProvider.future);
      return NotificationPermissionRepository(preferences);
    });

/// 提供页面按需读取的通知权限状态。
final notificationPermissionStatusProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(notificationPermissionServiceProvider).isNotificationPermissionEnabled();
});

/// 应用级通知权限状态。
class AppNotificationPermissionState {
  const AppNotificationPermissionState({required this.isEnabled});

  final bool isEnabled;
}

/// 管理首次安装自动请求、设置页跳转和回前台后的权限刷新。
class AppNotificationPermissionNotifier
    extends AsyncNotifier<AppNotificationPermissionState> {
  @override
  Future<AppNotificationPermissionState> build() async {
    final service = ref.read(notificationPermissionServiceProvider);
    final repository = await ref.read(
      notificationPermissionRepositoryProvider.future,
    );
    var isEnabled = false;
    try {
      isEnabled = await service.isNotificationPermissionEnabled();
    } catch (_) {
      return const AppNotificationPermissionState(isEnabled: false);
    }

    if (!repository.hasCompletedInitialRequest) {
      try {
        if (!isEnabled) {
          isEnabled = await service.requestNotificationPermission();
        }
      } catch (_) {
        isEnabled = false;
      } finally {
        // 请求被拒绝也属于已完成首次询问，后续启动不再自动打扰用户。
        await repository.markInitialRequestCompleted();
      }
    }
    return AppNotificationPermissionState(isEnabled: isEnabled);
  }

  /// 打开系统 App 设置页，供用户手动修改通知权限。
  Future<void> openSettings() async {
    try {
      await ref.read(notificationPermissionServiceProvider).openAppSettings();
    } catch (_) {
      // 设置页打开失败不影响欢迎流程，用户仍可继续进入首页。
    }
  }

  /// App 回到前台时重新读取系统权限。
  Future<void> refresh() async {
    try {
      final isEnabled = await ref
          .read(notificationPermissionServiceProvider)
          .isNotificationPermissionEnabled();
      state = AsyncData(AppNotificationPermissionState(isEnabled: isEnabled));
      ref.invalidate(notificationPermissionStatusProvider);
    } catch (_) {
      // 回前台刷新失败时保留原状态，避免权限检查阻断页面。
    }
  }
}

/// 提供整个应用共享的通知权限生命周期状态。
final appNotificationPermissionProvider = AsyncNotifierProvider<
  AppNotificationPermissionNotifier,
  AppNotificationPermissionState
>(AppNotificationPermissionNotifier.new);
