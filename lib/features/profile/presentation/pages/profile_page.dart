// 展示用户资料、设置入口和账号操作。
// 退出和注销由 ProfileAccountViewModel 编排，页面只负责确认、反馈和导航。

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:nalo/features/home/presentation/widgets/referral_program_card.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/profile/presentation/pages/about_page.dart';
import 'package:nalo/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:nalo/features/profile/presentation/pages/help_faq_page.dart';
import 'package:nalo/features/profile/presentation/pages/privacy_data_page.dart';
import 'package:nalo/features/profile/presentation/pages/profile_notifications_page.dart';
import 'package:nalo/features/profile/providers/profile_ui_provider.dart';
import 'package:nalo/features/profile/view_models/profile_account_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Nalo 个人中心页面。
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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final didLogout = await ref
        .read(profileAccountViewModelProvider.notifier)
        .logout();
    if (!context.mounted || !didLogout) return;
    context.go(AuthEntryPage.path);
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently deactivate your Nalo account and sign you out. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (didConfirm != true || !context.mounted) return;

    final didDeactivate = await ref
        .read(profileAccountViewModelProvider.notifier)
        .deactivate();
    if (!context.mounted) return;
    if (didDeactivate) {
      context.go(AuthEntryPage.path);
      return;
    }
    final message = ref.read(profileAccountViewModelProvider).errorMessage;
    if (message != null) {
      BotToast.showText(text: message, align: Alignment.center);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(profileUiProvider);
    final accountState = ref.watch(profileAccountViewModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: Stack(
        children: [
          SafeArea(
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
                  const SizedBox(height: 28),
                  _AccountActionButton(
                    label: 'Log out',
                    onPressed: () => _logout(context, ref),
                  ),
                  const SizedBox(height: 12),
                  _AccountActionButton(
                    label: 'Delete account',
                    foregroundColor: const Color(0xFFC62828),
                    borderColor: const Color(0xFFE6B8B8),
                    onPressed: () => _deactivate(context, ref),
                  ),
                  const SizedBox(height: 38),
                  const MedicalDisclaimerFooter(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (accountState.isLoading) const _ProfileLoadingOverlay(),
        ],
      ),
    );
  }
}

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
    required this.label,
    required this.onPressed,
    this.foregroundColor = const Color(0xFF111113),
    this.borderColor = const Color(0xFFD8D8DA),
  });

  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor),
          overlayColor: Colors.transparent,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ProfileLoadingOverlay extends StatelessWidget {
  const _ProfileLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(dismissible: false, color: Color(0x52000000)),
          Center(
            child: SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ],
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
