import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/features/full_tend/presentation/pages/full_tend_page.dart';
import 'package:tester_kit/features/home/presentation/widgets/home_bottom_tabs.dart';
import 'package:tester_kit/features/home/presentation/widgets/home_test_report_card.dart';
import 'package:tester_kit/features/home/presentation/widgets/main_page_header.dart';
import 'package:tester_kit/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:tester_kit/features/home/presentation/widgets/recommended_test_kit_card.dart';
import 'package:tester_kit/features/home/presentation/widgets/referral_program_card.dart';
import 'package:tester_kit/features/home/presentation/widgets/test_trend_section.dart';
import 'package:tester_kit/features/profile/presentation/pages/profile_page.dart';
import 'package:tester_kit/features/shop/presentation/pages/shop_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tester_kit/features/test_flow/presentation/pages/test_flow_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  static const path = '/home';
  static const shopPath = '$path?tab=shop';

  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _homeIndex = 0;
  static const _shopIndex = 1;
  static const _referralCode = '7XY212AS0W0H';
  static final _shareLink = Uri.parse(
    'https://test-store-001-55rykspg.myshopify.com/discount/7XY212AS0W0H?redirect=%2Fcollections%2F%E5%95%86%E5%93%81%E6%A0%87%E9%A2%98-01',
  );

  late int _selectedIndex;
  bool _isReferralVisible = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex == _shopIndex ? _shopIndex : _homeIndex;
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openTestFlow() => context.push(TestFlowPage.path);

  void _openProfile() => context.push(ProfilePage.path);

  void _showLearnMoreToast() {
    // TODO: <pf> Open the Testosterone kit details after the product page is implemented.
    BotToast.showText(text: 'Testosterone kit details are coming soon', align: Alignment.center);
  }

  void _openFullTend() => context.push(FullTendPage.path);

  void _dismissReferral() {
    setState(() => _isReferralVisible = false);
  }

  Future<void> _copyReferralCode() async {
    await Clipboard.setData(const ClipboardData(text: _referralCode));
    BotToast.showText(text: 'Referral code copied', align: Alignment.center);
  }

  Future<void> _openShareLink() async {
    final opened = await launchUrl(_shareLink, mode: LaunchMode.externalApplication);
    if (!opened) BotToast.showText(text: 'Unable to open share link', align: Alignment.center);
  }

  void _showMessageToast() {
    // TODO: <pf> Open the prefilled message composer when referral messaging is implemented.
    BotToast.showText(text: 'Message sharing is coming soon', align: Alignment.center);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF2F0C9), Color(0xFFE8ECEC), Color(0xFFB9BFF1)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _HomeTab(
                onMinePressed: _openProfile,
                onLearnMorePressed: _showLearnMoreToast,
                onFullTrendPressed: _openFullTend,
                isReferralVisible: _isReferralVisible,
                referralCode: _referralCode,
                onReferralDismissed: _dismissReferral,
                onReferralCopyPressed: _copyReferralCode,
                onShareLinkPressed: _openShareLink,
                onMessagePressed: _showMessageToast,
              ),
              ShopPage(onMinePressed: _openProfile),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: HomeBottomTabs(
          selectedIndex: _selectedIndex,
          homeIndex: _homeIndex,
          shopIndex: _shopIndex,
          onTabSelected: _selectTab,
          onCreatePressed: _openTestFlow,
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.onMinePressed,
    required this.onLearnMorePressed,
    required this.onFullTrendPressed,
    required this.isReferralVisible,
    required this.referralCode,
    required this.onReferralDismissed,
    required this.onReferralCopyPressed,
    required this.onShareLinkPressed,
    required this.onMessagePressed,
  });

  final VoidCallback onMinePressed;
  final VoidCallback onLearnMorePressed;
  final VoidCallback onFullTrendPressed;
  final bool isReferralVisible;
  final String referralCode;
  final VoidCallback onReferralDismissed;
  final VoidCallback onReferralCopyPressed;
  final VoidCallback onShareLinkPressed;
  final VoidCallback onMessagePressed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                MainPageHeader(headline: 'Good morning', onMinePressed: onMinePressed),
                const SizedBox(height: 34),
                const HomeTestReportCard(),
                const SizedBox(height: 18),
                RecommendedTestKitCard(onLearnMorePressed: onLearnMorePressed),
                const SizedBox(height: 32),
                TestTrendSection(onFullPressed: onFullTrendPressed),
                if (isReferralVisible) ...[
                  const SizedBox(height: 20),
                  ReferralProgramCard(
                    referralCode: referralCode,
                    onDismissed: onReferralDismissed,
                    onCopyPressed: onReferralCopyPressed,
                    onShareLinkPressed: onShareLinkPressed,
                    onMessagePressed: onMessagePressed,
                  ),
                ],
                const SizedBox(height: 38),
                const MedicalDisclaimerFooter(),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(hasScrollBody: false, child: SizedBox()),
      ],
    );
  }
}
