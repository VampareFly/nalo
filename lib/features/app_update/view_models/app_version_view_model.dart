// 管理单次冷启动中的版本检查节流与更新结果。
// 每次冷启动首次进入 Home Tab 时调用 checkOnce，失败仅记录日志，不阻塞用户。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/app/config/app_version_provider.dart';
import 'package:nalo/core/device/device_id_provider.dart';
import 'package:nalo/core/logging/logger_provider.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/app_update/models/app_version_update.dart';
import 'package:nalo/features/app_update/repositories/app_version_repository.dart';
import 'package:nalo/features/app_update/services/app_version_service.dart';

/// 管理本次进程生命周期内的版本检查结果。
class AppVersionViewModel extends Notifier<AsyncValue<AppVersionUpdate?>> {
  bool _hasCheckedThisLaunch = false;

  @override
  AsyncValue<AppVersionUpdate?> build() => const AsyncData(null);

  /// 每次冷启动最多检查一次；请求失败时静默结束且不在本次启动重试。
  Future<void> checkOnce() async {
    if (_hasCheckedThisLaunch) return;
    _hasCheckedThisLaunch = true;
    try {
      final repository = await ref.read(appVersionRepositoryProvider.future);
      final update = await repository.checkVersion();
      if (update.hasUpdate) state = AsyncData(update);
    } catch (error, stackTrace) {
      ref.read(loggerProvider).e(
        'App version check failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 弹窗完成处理后清除待展示结果，避免后续页面监听重复消费。
  void markHandled() => state = const AsyncData(null);
}

/// 注入版本检查 Repository 及其平台与网络依赖。
final appVersionRepositoryProvider = FutureProvider<AppVersionRepository>((
  ref,
) async {
  final apiClient = await ref.watch(businessApiClientProvider.future);
  final packageInfo = await ref.watch(appPackageInfoProvider.future);
  return AppVersionRepository(
    service: AppVersionService(apiClient),
    packageInfo: packageInfo,
    deviceIdService: ref.watch(deviceIdServiceProvider),
  );
});

/// 提供当前冷启动共享的版本检查状态。
final appVersionViewModelProvider =
    NotifierProvider<AppVersionViewModel, AsyncValue<AppVersionUpdate?>>(
      AppVersionViewModel.new,
    );
