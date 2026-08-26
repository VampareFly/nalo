// 承载新版首页与 Shop Tab，并统一处理页面访问、导航和曝光周期。
// Tab 重新进入或从 Flutter 子页面返回时，为 Shop 开启新一轮商品曝光。

import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
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
import 'package:nalo/features/test_flow/presentation/pages/test_flow_page.dart';
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
  int _shopExposureCycle = 0;
  bool _hasRenderedFirstFrame = false;
  bool _isVersionDialogVisible = false;
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
    if (state == AppLifecycleState.resumed) {
      ref.read(appNotificationPermissionProvider.notifier).refresh();
      if (_selectedIndex == _homeIndex) _refreshHome();
    }
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      if (index == _shopIndex) {
        _hasOpenedShop = true;
        _shopExposureCycle++;
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
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.isForceUpdate,
      builder: (dialogContext) => VersionUpdateDialog(
        update: update,
        onUpdatePressed: () => _openUpdate(update, dialogContext),
        onLaterPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
    _isVersionDialogVisible = false;
    ref.read(appVersionViewModelProvider.notifier).markHandled();
  }

  Future<void> _openUpdate(
    AppVersionUpdate update,
    BuildContext dialogContext,
  ) async {
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

  void _refreshHome() => ref.invalidate(homeDashboardProvider);

  Future<void> _openTestFlow() async {
    await context.push(TestFlowPage.path);
    if (mounted && _selectedIndex == _homeIndex) _refreshHome();
  }

  Future<void> _openProfile() async {
    final shouldRestartShopExposure = _selectedIndex == _shopIndex;
    await context.push(ProfilePage.path);
    if (mounted && shouldRestartShopExposure) {
      setState(() => _shopExposureCycle++);
    }
    if (mounted && _selectedIndex == _homeIndex) _refreshHome();
  }

  Future<void> _openTestHistory() async {
    await context.push(TestHistoryPage.path);
    if (mounted) _refreshHome();
  }

  void _showReferralPlaceholder() {
    // TODO: <pf> Referral 目标页或分享方式确认后接入正式交互。
    BotToast.showText(
      text: 'Referral details are coming soon',
      align: Alignment.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8E0),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeDashboard(
            onProfilePressed: _openProfile,
            onScanPressed: _openTestFlow,
            onHistoryPressed: _openTestHistory,
            onReferralPressed: _showReferralPlaceholder,
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
        onCreatePressed: _openTestFlow,
      ),
    );
  }
}
