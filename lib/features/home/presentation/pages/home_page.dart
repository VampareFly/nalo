// 承载首页与 Shop Tab，并统一处理页面访问、导航、曝光和前后台刷新周期。
// 首页仅在 App 确实进入后台后恢复时刷新，避免冷启动首次 resumed 重复请求。

import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/app/config/app_version_provider.dart';
import 'package:nalo/app/navigation/initial_page_ready_provider.dart';
import 'package:nalo/app/navigation/test_flow_entry_coordinator.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/sharing/platform_share_service.dart';
import 'package:nalo/features/app_update/models/app_version_update.dart';
import 'package:nalo/features/app_update/presentation/widgets/version_update_dialog.dart';
import 'package:nalo/features/app_update/view_models/app_version_view_model.dart';
import 'package:nalo/features/home/presentation/widgets/home_bottom_tabs.dart';
import 'package:nalo/features/home/presentation/widgets/home_dashboard.dart';
import 'package:nalo/features/home/presentation/pages/test_history_page.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/profile/presentation/pages/profile_page.dart';
import 'package:nalo/features/shop/presentation/pages/shop_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// 登录后的主容器页面，负责首页、Shop 与 Scan 入口的协调。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  static const path = '/home';
  static const shopPath = '$path?tab=shop';

  final int initialIndex;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  static const _homeIndex = 0;
  static const _shopIndex = 1;
  late int _selectedIndex;
  late bool _hasOpenedShop;
  int _homeExposureCycle = 0;
  int _shopExposureCycle = 0;
  bool _hasRenderedFirstFrame = false;
  bool _isVersionDialogVisible = false;
  bool _hasEnteredBackground = false;
  AppVersionUpdate? _pendingVersionUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex == _shopIndex
        ? _shopIndex
        : _homeIndex;
    _hasOpenedShop = _selectedIndex == _shopIndex;
    ref.listenManual(
      appVersionViewModelProvider,
      (_, next) => _handleVersionState(next),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(initialPageReadyProvider.notifier).markReady();
      unawaited(ref.reportAnalyticsPageView(_selectedPageName));
      _hasRenderedFirstFrame = true;
      final update = _pendingVersionUpdate;
      _pendingVersionUpdate = null;
      if (update != null) _showVersionDialog(update);
    });
    if (_selectedIndex == _homeIndex) {
      _checkVersion();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _hasEnteredBackground = true;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(appNotificationPermissionProvider.notifier).refresh();
      if (_hasEnteredBackground && _selectedIndex == _homeIndex) {
        _refreshHome();
      }
      _hasEnteredBackground = false;
    }
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      if (index == _shopIndex) {
        _hasOpenedShop = true;
        _shopExposureCycle++;
      } else {
        _homeExposureCycle++;
      }
    });
    unawaited(ref.reportAnalyticsPageView(_selectedPageName));
    if (index == _homeIndex) {
      _refreshHome();
      _checkVersion();
    }
  }

  AnalyticsPageName get _selectedPageName => _selectedIndex == _shopIndex
      ? AnalyticsPageName.tabShop
      : AnalyticsPageName.tabHome;

  void _checkVersion() {
    if (!mounted || _selectedIndex != _homeIndex) return;
    ref.read(appVersionViewModelProvider.notifier).checkOnce();
  }

  void _handleVersionState(AsyncValue<AppVersionUpdate?> next) {
    final update = next.asData?.value;
    if (update == null || _isVersionDialogVisible) return;
    if (!_hasRenderedFirstFrame) {
      _pendingVersionUpdate = update;
      return;
    }
    _showVersionDialog(update);
  }

  Future<void> _showVersionDialog(AppVersionUpdate update) async {
    if (!mounted || _isVersionDialogVisible) return;
    _isVersionDialogVisible = true;
    unawaited(
      ref.report(
        AnalyticsEvent.appUpdateAlertView,
        properties: _appUpdateProperties(update),
      ),
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.isForceUpdate,
      builder: (dialogContext) => VersionUpdateDialog(
        update: update,
        onUpdatePressed: () => _openUpdate(update, dialogContext),
        onLaterPressed: () => _closeUpdateLater(update, dialogContext),
      ),
    );
    _isVersionDialogVisible = false;
    ref.read(appVersionViewModelProvider.notifier).markHandled();
  }

  Future<void> _openUpdate(
    AppVersionUpdate update,
    BuildContext dialogContext,
  ) async {
    unawaited(
      ref.report(
        AnalyticsEvent.appUpdateClick,
        properties: _appUpdateProperties(
          update,
          action: AnalyticsUpdateAction.update,
        ),
      ),
    );
    final uri = update.updateUrl;
    if (uri == null) {
      BotToast.showText(
        text: 'Unable to open the update page.',
        align: Alignment.center,
      );
      return;
    }
    final didOpen = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!didOpen) {
      BotToast.showText(
        text: 'Unable to open the update page.',
        align: Alignment.center,
      );
      return;
    }
    if (!update.isForceUpdate && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  void _closeUpdateLater(AppVersionUpdate update, BuildContext dialogContext) {
    unawaited(
      ref.report(
        AnalyticsEvent.appUpdateClick,
        properties: _appUpdateProperties(
          update,
          action: AnalyticsUpdateAction.later,
        ),
      ),
    );
    Navigator.of(dialogContext).pop();
  }

  Map<AnalyticsEventProperty, Object> _appUpdateProperties(
    AppVersionUpdate update, {
    AnalyticsUpdateAction? action,
  }) {
    final packageInfo = ref.read(appPackageInfoProvider).asData?.value;
    return {
      AnalyticsEventProperty.pageName: _selectedPageName.value,
      AnalyticsEventProperty.currentVersion: packageInfo?.version ?? '',
      AnalyticsEventProperty.targetVersion: update.latestVersion,
      AnalyticsEventProperty.updateType: update.isForceUpdate
          ? AnalyticsUpdateType.force.value
          : AnalyticsUpdateType.optional.value,
      if (action != null) ...{
        AnalyticsEventProperty.action: action.value,
        AnalyticsEventProperty.url: update.updateUrl?.toString() ?? '',
      },
    };
  }

  void _refreshHome() => ref.invalidate(homeIndexProvider);

  Future<void> _openTestFlow(
    AnalyticsTestStartPosition position, {
    int? totalTestCount,
  }) async {
    final source = switch (position) {
      AnalyticsTestStartPosition.homeCard => AnalyticsTestFlowSource.homeCard,
      AnalyticsTestStartPosition.bottomScan => AnalyticsTestFlowSource.tabScan,
      AnalyticsTestStartPosition.testHistoryEmpty =>
        AnalyticsTestFlowSource.testHistoryEmpty,
    };
    await ref
        .read(testFlowEntryCoordinatorProvider)
        .open(
          source: source,
          pageName: _selectedPageName,
          position: position,
          totalTestCount: totalTestCount ?? _currentTotalTestCount,
        );
    if (mounted) _resumeSelectedTabAfterChild();
  }

  Future<void> _openProfile() async {
    unawaited(
      ref.report(
        AnalyticsEvent.profileClick,
        properties: {AnalyticsEventProperty.pageName: _selectedPageName.value},
      ),
    );
    await context.push(ProfilePage.path);
    if (mounted) _resumeSelectedTabAfterChild();
  }

  Future<void> _openTestHistory(int totalTestCount) async {
    unawaited(
      ref.report(
        AnalyticsEvent.testHistoryEntryClick,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.tabHome.value,
          AnalyticsEventProperty.totalTestCount: totalTestCount,
        },
      ),
    );
    await context.push(TestHistoryPage.path);
    if (mounted) _resumeSelectedTabAfterChild();
  }

  Future<void> _shareReferral() async {
    final offer = ref.read(homeDashboardProvider).asData?.value.referralOffer;
    if (offer == null) return;
    unawaited(
      ref.report(
        AnalyticsEvent.referralClick,
        properties: referralAnalyticsProperties(
          pageName: AnalyticsPageName.tabHome,
          url: offer.actionUrl,
          advocateRewardType: offer.advocateRewardType,
          advocateRewardValue: offer.advocateRewardValue,
          advocateRewardUnit: offer.advocateRewardUnit,
          friendRewardType: offer.friendRewardType,
          friendRewardValue: offer.friendRewardValue,
          friendRewardUnit: offer.friendRewardUnit,
        ),
      ),
    );
    try {
      await ref
          .read(platformShareServiceProvider)
          .shareLink(offer.actionUrl, message: offer.shareText);
    } on Object {
      if (!mounted) return;
      BotToast.showText(
        text: 'Unable to share referral link',
        align: Alignment.center,
      );
    }
  }

  int get _currentTotalTestCount {
    final data = ref.read(homeDashboardProvider).asData?.value;
    return data != null && data.hasIndexData ? data.totalTestCount : -1;
  }

  void _resumeSelectedTabAfterChild() {
    setState(() {
      if (_selectedIndex == _homeIndex) {
        _homeExposureCycle++;
      } else {
        _shopExposureCycle++;
      }
    });
    unawaited(ref.reportAnalyticsPageView(_selectedPageName));
    if (_selectedIndex == _homeIndex) _refreshHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8E0),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeDashboard(
            isActive: _selectedIndex == _homeIndex,
            exposureCycle: _homeExposureCycle,
            onProfilePressed: _openProfile,
            onScanPressed: (totalTestCount) => _openTestFlow(
              AnalyticsTestStartPosition.homeCard,
              totalTestCount: totalTestCount,
            ),
            onHistoryPressed: _openTestHistory,
            onReferralPressed: _shareReferral,
          ),
          _hasOpenedShop
              ? ShopPage(
                  isActive: _selectedIndex == _shopIndex,
                  exposureCycle: _shopExposureCycle,
                  onMinePressed: _openProfile,
                )
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: HomeBottomTabs(
        selectedIndex: _selectedIndex,
        homeIndex: _homeIndex,
        shopIndex: _shopIndex,
        onTabSelected: _selectTab,
        onCreatePressed: () =>
            _openTestFlow(AnalyticsTestStartPosition.bottomScan),
      ),
    );
  }
}
