// 承载新版首页与 Shop Tab，并统一处理页面级导航和生命周期事件。
// Home/Shop 使用 IndexedStack 保留状态，中间 Scan 始终进入现有检测流程。

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/home/presentation/widgets/home_bottom_tabs.dart';
import 'package:nalo/features/home/presentation/widgets/home_dashboard.dart';
import 'package:nalo/features/home/presentation/pages/test_history_page.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/profile/presentation/pages/profile_page.dart';
import 'package:nalo/features/shop/presentation/pages/shop_page.dart';
import 'package:nalo/features/test_flow/presentation/pages/test_flow_page.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex == _shopIndex ? _shopIndex : _homeIndex;
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

  void _selectTab(int index) => setState(() => _selectedIndex = index);

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
          SafeArea(child: ShopPage(onMinePressed: _openProfile)),
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
