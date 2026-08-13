import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:nalo/features/home/presentation/widgets/referral_program_card.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/profile/presentation/pages/about_page.dart';
import 'package:nalo/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:nalo/features/profile/presentation/pages/help_faq_page.dart';
import 'package:nalo/features/profile/presentation/pages/privacy_data_page.dart';
import 'package:nalo/features/profile/presentation/pages/profile_notifications_page.dart';
import 'package:nalo/features/profile/providers/profile_ui_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static const path = '/profile';
  static const _referralCode = '7XY212AS0W0H';
  static final _shareLink = Uri.parse(
    'https://test-store-001-55rykspg.myshopify.com/discount/7XY212AS0W0H?redirect=%2Fcollections%2F%E5%95%86%E5%93%81%E6%A0%87%E9%A2%98-01',
  );

  void _showComingSoon(String feature) {
    // TODO: <pf> Open the corresponding profile destination after it is implemented.
    BotToast.showText(text: '$feature is coming soon', align: Alignment.center);
  }

  Future<void> _copyReferralCode() async {
    await Clipboard.setData(const ClipboardData(text: _referralCode));
    BotToast.showText(text: 'Referral code copied', align: Alignment.center);
  }

  Future<void> _openShareLink() async {
    final opened = await launchUrl(_shareLink, mode: LaunchMode.externalApplication);
    if (!opened) BotToast.showText(text: 'Unable to open share link', align: Alignment.center);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(profileUiProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 44),
              sliver: SliverList.list(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF606064),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      icon: const Icon(Icons.chevron_left, size: 22),
                      label: const Text('Back'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Color(0xFF050505),
                      fontFamily: 'Times New Roman',
                      fontSize: 28,
                      height: 1,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 34),
                  _ProfileSummaryCard(
                    name: uiState.displayName,
                    onPressed: () => context.push(EditProfilePage.path),
                  ),
                  const SizedBox(height: 18),
                  _SettingsCard(
                    title: 'ACCOUNT',
                    children: [
                      _SettingsActionRow(label: 'Edit profile', onPressed: () => context.push(EditProfilePage.path)),
                      const _NotificationPermissionRow(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SettingsCard(
                    title: 'SUPPORT',
                    children: [
                      _SettingsActionRow(label: 'Help & FAQ', onPressed: () => context.push(HelpFaqPage.path)),
                      _SettingsActionRow(label: 'Privacy & data', onPressed: () => context.push(PrivacyDataPage.path)),
                      _SettingsActionRow(label: 'About Nola Test Kit', onPressed: () => context.push(AboutPage.path)),
                    ],
                  ),
                  if (uiState.isReferralVisible) ...[
                    const SizedBox(height: 28),
                    ReferralProgramCard(
                      referralCode: _referralCode,
                      onDismissed: ref.read(profileUiProvider.notifier).dismissReferral,
                      onCopyPressed: _copyReferralCode,
                      onShareLinkPressed: _openShareLink,
                      onMessagePressed: () => _showComingSoon('Message sharing'),
                    ),
                  ],
                  const SizedBox(height: 38),
                  const MedicalDisclaimerFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.name, required this.onPressed});

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(27),
      shadowColor: Colors.black.withValues(alpha: 0.12),
      elevation: 5,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(27),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFF91A2E4),
                child: Text('?', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Add your name' : name,
                  style: const TextStyle(color: Color(0xFF111113), fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 13),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF77777A),
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
          ),
          for (final child in children) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
            child,
          ],
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              const Icon(Icons.chevron_right, color: Color(0xFF68686B), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationPermissionRow extends ConsumerStatefulWidget {
  const _NotificationPermissionRow();

  @override
  ConsumerState<_NotificationPermissionRow> createState() => _NotificationPermissionRowState();
}

class _NotificationPermissionRowState extends ConsumerState<_NotificationPermissionRow> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationPermissionStatusProvider);
    }
  }

  Future<void> _handleSwitchPressed() async {
    final service = ref.read(notificationPermissionServiceProvider);
    final isEnabled = await service.isNotificationPermissionEnabled();
    if (!mounted) return;

    if (!isEnabled) {
      await service.openAppSettings();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications are on'),
        content: const Text('To turn off push notifications, open your device settings and update the notification permission for Nola Test Kit.'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF050505),
              minimumSize: const Size(120, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(
      notificationPermissionStatusProvider.select(
        (value) => value.when(data: (enabled) => enabled, loading: () => false, error: (error, stackTrace) => false),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 12, 0),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.push(ProfileNotificationsPage.path),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            Switch(
              value: isEnabled,
              onChanged: (_) => _handleSwitchPressed(),
              activeTrackColor: const Color(0xFF91A2E4),
              inactiveTrackColor: const Color(0xFFE6E6E7),
              inactiveThumbColor: Colors.white,
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}
