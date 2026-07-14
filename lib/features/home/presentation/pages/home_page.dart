import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/features/full_tend/presentation/pages/full_tend_page.dart';
import 'package:tester_kit/features/home/presentation/widgets/home_bottom_tabs.dart';
import 'package:tester_kit/features/home/presentation/widgets/home_test_report_card.dart';
import 'package:tester_kit/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:tester_kit/features/home/presentation/widgets/recommended_test_kit_card.dart';
import 'package:tester_kit/features/home/presentation/widgets/referral_program_card.dart';
import 'package:tester_kit/features/home/presentation/widgets/test_trend_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const path = '/home';

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _homeIndex = 0;
  static const _shopIndex = 1;
  static const _referralCode = 'KNOW-15';

  int _selectedIndex = _homeIndex;
  bool _isReferralVisible = true;

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

  void _showMineToast() {
    // TODO: <pf> Replace the toast when the mine page is implemented.
    BotToast.showText(text: 'Mine is coming soon', align: Alignment.center);
  }

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

  void _showShareLinkToast() {
    // TODO: <pf> Open the system share sheet when referral sharing is implemented.
    BotToast.showText(text: 'Share link is coming soon', align: Alignment.center);
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
                onMinePressed: _showMineToast,
                onLearnMorePressed: _showLearnMoreToast,
                onFullTrendPressed: _openFullTend,
                isReferralVisible: _isReferralVisible,
                referralCode: _referralCode,
                onReferralDismissed: _dismissReferral,
                onReferralCopyPressed: _copyReferralCode,
                onShareLinkPressed: _showShareLinkToast,
                onMessagePressed: _showMessageToast,
              ),
              const _ShopTab(),
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
          onCreatePressed: _showCreateToast,
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
                _HomeHeader(onMinePressed: onMinePressed),
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
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
        const SliverFillRemaining(hasScrollBody: false, child: SizedBox()),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onMinePressed});

  final VoidCallback onMinePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NBG TEST KIT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF717174),
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Good morning',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF050505),
                  fontSize: 24,
                  height: 1,
                  fontFamily: 'Times New Roman',
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _MineButton(onPressed: onMinePressed),
      ],
    );
  }
}

class _MineButton extends StatelessWidget {
  const _MineButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: const Icon(Icons.person_outline, color: Color(0xFF050505), size: 24),
              ),
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFA9B5F4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        ],
      ),
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
