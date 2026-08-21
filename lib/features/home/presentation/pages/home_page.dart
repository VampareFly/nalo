// 承载新版首页与 Shop Tab，并统一处理页面级导航、版本检查和生命周期事件。
// 每次冷启动首次进入 Home Tab 时立即检查版本，Home/Shop 使用 IndexedStack 保留状态。

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/app_update/models/app_version_update.dart';
import 'package:nalo/features/app_update/presentation/widgets/version_update_dialog.dart';
import 'package:nalo/features/app_update/view_models/app_version_view_model.dart';
import 'package:nalo/features/home/presentation/widgets/home_bottom_tabs.dart';
import 'package:nalo/features/home/presentation/widgets/home_dashboard.dart';
import 'package:nalo/features/home/presentation/pages/test_history_page.dart';
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

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  static const _homeIndex = 0;
  static const _shopIndex = 1;
  late int _selectedIndex;
  late bool _hasOpenedShop;
  bool _hasRenderedFirstFrame = false;
  bool _isVersionDialogVisible = false;
  AppVersionUpdate? _pendingVersionUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex == _shopIndex ? _shopIndex : _homeIndex;
    _hasOpenedShop = _selectedIndex == _shopIndex;
    ref.listenManual(
      appVersionViewModelProvider,
      (_, next) => _handleVersionState(next),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    }
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == _shopIndex) _hasOpenedShop = true;
    });
    if (index == _homeIndex) {
      _checkVersion();
    }
  }

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

  void _openTestFlow() => context.push(TestFlowPage.path);

  void _openProfile() => context.push(ProfilePage.path);

  void _openTestHistory() => context.push(TestHistoryPage.path);

  void _showReferralPlaceholder() {
    // TODO: <pf> Referral 目标页或分享方式确认后接入正式交互。
    BotToast.showText(text: 'Referral details are coming soon', align: Alignment.center);
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
              ? ShopPage(onMinePressed: _openProfile)
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
