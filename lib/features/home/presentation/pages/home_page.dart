import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:tester_kit/features/home/presentation/widgets/home_bottom_tabs.dart';
import 'package:tester_kit/l10n/generated/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const path = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _homeIndex = 0;
  static const _shopIndex = 1;

  int _selectedIndex = _homeIndex;

  void _selectTab(int index) {
    final label = index == _homeIndex ? 'Home' : 'Shop';
    BotToast.showText(text: '$label is coming soon', align: Alignment.center);

    setState(() {
      _selectedIndex = index;
    });
  }

  void _showCreateToast() {
    BotToast.showText(text: 'Create is coming soon', align: Alignment.center);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeTab(appName: l10n.appName, welcomeMessage: l10n.welcomeMessage),
            const _ShopTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: HomeBottomTabs(
          selectedIndex: _selectedIndex,
          homeIndex: _homeIndex,
          shopIndex: _shopIndex,
          onTabSelected: _selectTab,
          onCreatePressed: _showCreateToast,
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.appName, required this.welcomeMessage});

  final String appName;
  final String welcomeMessage;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(pinned: true, title: Text(appName)),
        SliverFillRemaining(hasScrollBody: false, child: Center(child: Text(welcomeMessage))),
      ],
    );
  }
}

class _ShopTab extends StatelessWidget {
  const _ShopTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Shop'));
  }
}
