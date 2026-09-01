// 按 Figma 展示当前用户资料、检测统计、账号入口和账号操作。
// Widget 上报 Section 曝光与点击，账号请求结果由 ProfileAccountViewModel 上报。

import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:nalo/features/profile/view_models/profile_account_view_model.dart';
import 'package:nalo/features/profile/view_models/profile_view_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Nalo 个人中心主页。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  static const path = '/profile';

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  static const _deleteTitle = 'Delete account?';
  static const _deleteDescription =
      'This will permanently deactivate your Nalo account and sign you out. '
      'This action cannot be undone.';

  final Set<AnalyticsProfileSectionType> _viewedSections = {};
  bool _referralViewReported = false;
  int _exposureCycle = 0;
  double _testsCompletedVisibleFraction = 0;
  bool _ownsLoadingToast = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(profileViewModelProvider.notifier).load);
  }

  @override
  void dispose() {
    if (_ownsLoadingToast) EasyLoading.dismiss();
    super.dispose();
  }

  void _showComingSoon(String feature) {
    // TODO: <pf> 产品确认目标页面或链接后替换临时 Toast。
    BotToast.showText(text: '$feature is coming soon', align: Alignment.center);
  }

  void _openShopifyManage() {
    _reportAction(AnalyticsProfileActionType.manageShopifyAccount);
    // TODO: <pf> Shopify Customer accounts 管理 URL 确认后使用外部浏览器打开。
    BotToast.showText(
      text: 'Shopify account management is coming soon',
      align: Alignment.center,
    );
  }

  Future<void> _openReferralLink(String link) async {
    unawaited(
      ref.report(
        AnalyticsEvent.referralClick,
        properties: _referralProperties(link),
      ),
    );
    final uri = Uri.tryParse(link);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      BotToast.showText(
        text: 'Unable to open referral link',
        align: Alignment.center,
      );
    }
  }

  Future<void> _logout() async {
    _reportAction(AnalyticsProfileActionType.signOut);
    final didLogout = await ref
        .read(profileAccountViewModelProvider.notifier)
        .logout();
    if (!mounted || !didLogout) return;
    context.go(AuthEntryPage.path);
  }

  Future<void> _deactivate() async {
    _reportAction(AnalyticsProfileActionType.deleteAccount);
    await ref.report(
      AnalyticsEvent.profileDeleteAccountAlertView,
      properties: {
        AnalyticsEventProperty.pageName: AnalyticsPageName.profile.value,
        AnalyticsEventProperty.title: _deleteTitle,
        AnalyticsEventProperty.desc: _deleteDescription,
      },
    );
    if (!mounted) return;
    final didConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(_deleteTitle),
        content: const Text(_deleteDescription),
        actions: [
          TextButton(
            onPressed: () {
              unawaited(_reportDeleteAlertClick('2'));
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              unawaited(_reportDeleteAlertClick('1'));
              Navigator.of(dialogContext).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD4183D),
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (didConfirm != true || !mounted) return;

    final didDeactivate = await ref
        .read(profileAccountViewModelProvider.notifier)
        .deactivate();
    if (!mounted) return;
    if (didDeactivate) {
      context.go(AuthEntryPage.path);
      return;
    }
    final message = ref.read(profileAccountViewModelProvider).errorMessage;
    if (message != null) {
      BotToast.showText(text: message, align: Alignment.center);
    }
  }

  void _reportAction(AnalyticsProfileActionType action) {
    unawaited(
      ref.report(
        AnalyticsEvent.profileActionClick,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.profile.value,
          AnalyticsEventProperty.actionType: action.value,
        },
      ),
    );
  }

  Future<void> _openEditProfile() async {
    _reportAction(AnalyticsProfileActionType.editProfile);
    await context.push(EditProfilePage.path);
    if (!mounted) return;
    _viewedSections.clear();
    _referralViewReported = false;
    _exposureCycle++;
    setState(() {});
  }

  void _showTrackedComingSoon(
    AnalyticsProfileActionType action,
    String feature,
  ) {
    _reportAction(action);
    _showComingSoon(feature);
  }

  void _reportSectionVisibility(
    AnalyticsProfileSectionType section,
    double visibleFraction, {
    int? totalTestCount,
  }) {
    if (visibleFraction < 0.1 || !_viewedSections.add(section)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.profileSectionView,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.profile.value,
          AnalyticsEventProperty.sectionType: section.value,
          if (totalTestCount != null)
            AnalyticsEventProperty.totalTestCount: totalTestCount,
        },
      ),
    );
  }

  Future<void> _reportDeleteAlertClick(String action) {
    return ref.report(
      AnalyticsEvent.profileDeleteAccountAlertClick,
      properties: {
        AnalyticsEventProperty.pageName: AnalyticsPageName.profile.value,
        AnalyticsEventProperty.action: action,
      },
    );
  }

  Map<AnalyticsEventProperty, Object> _referralProperties(String url) => {
    AnalyticsEventProperty.pageName: AnalyticsPageName.profile.value,
    // TODO: <pf> 服务端提供真实折扣比例后替换固定值。
    AnalyticsEventProperty.discountPercent: 10,
    AnalyticsEventProperty.url: url,
  };

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileViewModelProvider);
    final user = profileState.user;
    ref.listen(
      profileAccountViewModelProvider.select((state) => state.isLoading),
      (previous, next) {
        if (next) {
          _ownsLoadingToast = true;
          EasyLoading.show();
        } else if (_ownsLoadingToast) {
          _ownsLoadingToast = false;
          EasyLoading.dismiss();
        }
      },
    );

    ref.listen(profileViewModelProvider.select((state) => state.errorMessage), (
      previous,
      next,
    ) {
      if (next != null && next != previous) {
        BotToast.showText(text: next, align: Alignment.center);
      }
    });
    ref.listen(
      profileViewModelProvider.select(
        (state) => state.user?.testInfo?.sumCount,
      ),
      (previous, next) {
        if (next == null) return;
        _reportSectionVisibility(
          AnalyticsProfileSectionType.testsCompleted,
          _testsCompletedVisibleFraction,
          totalTestCount: next,
        );
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEDE8E0),
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                  sliver: SliverList.list(
                    children: [
                      _Header(
                        onBack: () => context.pop(),
                        onEdit: user == null ? null : _openEditProfile,
                      ),
                      const SizedBox(height: 30),
                      _ProfileExposure(
                        keyName: 'tests-completed',
                        exposureCycle: _exposureCycle,
                        onVisibilityChanged: (fraction) {
                          _testsCompletedVisibleFraction = fraction;
                          final count = user?.testInfo?.sumCount;
                          if (count == null) return;
                          _reportSectionVisibility(
                            AnalyticsProfileSectionType.testsCompleted,
                            fraction,
                            totalTestCount: count,
                          );
                        },
                        child: _TestsCompletedCard(
                          count: user?.testInfo?.sumCount ?? 0,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ProfileExposure(
                        keyName: 'personal-information',
                        exposureCycle: _exposureCycle,
                        onVisibilityChanged: (fraction) =>
                            _reportSectionVisibility(
                              AnalyticsProfileSectionType.personalInformation,
                              fraction,
                            ),
                        child: _UserInfoCard(user: user),
                      ),
                      const SizedBox(height: 18),
                      _ProfileExposure(
                        keyName: 'shopify-account',
                        exposureCycle: _exposureCycle,
                        onVisibilityChanged: (fraction) =>
                            _reportSectionVisibility(
                              AnalyticsProfileSectionType.shopifyAccount,
                              fraction,
                            ),
                        child: _ShopifyAccountCard(
                          email: _displayValue(user?.email),
                          onManage: _openShopifyManage,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ProfileExposure(
                        keyName: 'settings-menu',
                        exposureCycle: _exposureCycle,
                        onVisibilityChanged: (fraction) =>
                            _reportSectionVisibility(
                              AnalyticsProfileSectionType.settingsMenu,
                              fraction,
                            ),
                        child: _MenuCard(
                          items: [
                            _MenuItem(
                              label: 'Notification settings',
                              onPressed: () => _showTrackedComingSoon(
                                AnalyticsProfileActionType.notificationSettings,
                                'Notification settings',
                              ),
                            ),
                            _MenuItem(
                              label: 'Privacy policy',
                              onPressed: () => _showTrackedComingSoon(
                                AnalyticsProfileActionType.privacyPolicy,
                                'Privacy policy',
                              ),
                            ),
                            _MenuItem(
                              label: 'Terms of service',
                              onPressed: () => _showTrackedComingSoon(
                                AnalyticsProfileActionType.termsOfService,
                                'Terms of service',
                              ),
                            ),
                            _MenuItem(
                              label: 'Help & support',
                              onPressed: () => _showTrackedComingSoon(
                                AnalyticsProfileActionType.helpAndSupport,
                                'Help & support',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user?.referralCard case final referralCard?) ...[
                        const SizedBox(height: 18),
                        VisibilityDetector(
                          key: ValueKey('profile-$_exposureCycle-referral'),
                          onVisibilityChanged: (info) {
                            if (_referralViewReported ||
                                info.visibleFraction < 0.1) {
                              return;
                            }
                            _referralViewReported = true;
                            unawaited(
                              ref.report(
                                AnalyticsEvent.referralView,
                                properties: _referralProperties(
                                  referralCard.actionUrl,
                                ),
                              ),
                            );
                          },
                          child: _ReferralCard(
                            referralCard: referralCard,
                            onPressed: () =>
                                _openReferralLink(referralCard.actionUrl),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _ProfileExposure(
                        keyName: 'account-actions',
                        exposureCycle: _exposureCycle,
                        onVisibilityChanged: (fraction) =>
                            _reportSectionVisibility(
                              AnalyticsProfileSectionType.accountActions,
                              fraction,
                            ),
                        child: Column(
                          children: [
                            _SignOutButton(onPressed: _logout),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: _deactivate,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF9FA89E),
                                minimumSize: const Size.fromHeight(42),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Delete account'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayValue(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '—' : text;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onEdit});

  final VoidCallback onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton.filled(
        onPressed: onBack,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.07),
          foregroundColor: const Color(0xFF1A2433),
        ),
        icon: const Icon(Icons.arrow_back, size: 20),
      ),
      const Expanded(
        child: Text(
          'Profile',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF1A2433),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      OutlinedButton(
        onPressed: onEdit,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF008BC7),
          side: const BorderSide(color: Color(0xFF008BC7), width: 1.5),
          minimumSize: const Size(58, 40),
          shape: const StadiumBorder(),
        ),
        child: const Text('Edit'),
      ),
    ],
  );
}

class _TestsCompletedCard extends StatelessWidget {
  const _TestsCompletedCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
    decoration: BoxDecoration(
      color: const Color(0xFF008BC7),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TESTS COMPLETED',
                style: TextStyle(
                  color: Color(0x8CFFFFFF),
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0x1FFFFFFF),
          child: Icon(
            Icons.emoji_events_outlined,
            color: Color(0xFFFFDA59),
            size: 29,
          ),
        ),
      ],
    ),
  );
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({required this.user});

  final AppUserInfo? user;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('NAME', _value(user?.fullName)),
      ('EMAIL', _value(user?.email)),
      ('DATE OF BIRTH', _value(user?.birthDay)),
      ('BIOLOGICAL SEX', _gender(user?.gender)),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Color(0x0D000000)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Text(
                    rows[index].$1,
                    style: const TextStyle(
                      color: Color(0xFF9FA89E),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      rows[index].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF1A2433),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _value(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _gender(int? value) => switch (value) {
    1 => 'Male',
    2 => 'Female',
    _ => '—',
  };
}

class _ShopifyAccountCard extends StatelessWidget {
  const _ShopifyAccountCard({required this.email, required this.onManage});

  final String email;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onManage,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF96BF48),
              child: SvgPicture.asset(
                'assets/icons/shopify.svg',
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shopify account',
                    style: TextStyle(
                      color: Color(0xFF1A2433),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Connected · $email',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9FA89E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const ShapeDecoration(
                color: Color(0x1F96BF48),
                shape: StadiumBorder(),
              ),
              child: const Text(
                'Manage',
                style: TextStyle(
                  color: Color(0xFF5A8A1A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MenuItem {
  const _MenuItem({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 1, color: Color(0x0D000000)),
          InkWell(
            onTap: items[index].onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      items[index].label,
                      style: const TextStyle(
                        color: Color(0xFF1A2433),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF9FA89E),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.referralCard, required this.onPressed});

  final UserReferralCard referralCard;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFDDA7C),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          referralCard.title,
          style: const TextStyle(
            color: Color(0xFF1A2433),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          referralCard.description,
          style: const TextStyle(
            color: Color(0xFF5A4200),
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A2433),
              foregroundColor: const Color(0xFFFDDA7C),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(referralCard.buttonText),
          ),
        ),
      ],
    ),
  );
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD4183D),
        side: const BorderSide(color: Color(0xFFD4183D), width: 1.5),
        minimumSize: const Size.fromHeight(46),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: const Text('Sign out'),
    ),
  );
}

/// 将 Profile 区域的可见比例交给页面统一去重和上报。
class _ProfileExposure extends StatelessWidget {
  const _ProfileExposure({
    required this.keyName,
    required this.exposureCycle,
    required this.onVisibilityChanged,
    required this.child,
  });

  final String keyName;
  final int exposureCycle;
  final ValueChanged<double> onVisibilityChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: ValueKey<String>('profile-$exposureCycle-$keyName'),
    onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
    child: child,
  );
}
