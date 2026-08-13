import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/profile/presentation/widgets/profile_subpage_widgets.dart';
import 'package:nalo/features/profile/providers/profile_ui_provider.dart';

class ProfileNotificationsPage extends ConsumerWidget {
  const ProfileNotificationsPage({super.key});

  static const path = '/profile/notifications';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileUiProvider);
    final notifier = ref.read(profileUiProvider.notifier);

    return ProfileSubpageScaffold(
      title: 'Notifications',
      children: [
        const Text(
          'Choose which reminders you receive. Your device settings can still override these preferences.',
          style: TextStyle(color: Color(0xFF717277), fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        ProfileSectionCard(
          title: 'PREFERENCES',
          children: [
            ProfileSettingRow(
              title: 'Allow notifications',
              subtitle: 'Master switch for all Nola reminders',
              trailing: Switch(value: state.notificationsEnabled, onChanged: notifier.setNotificationsEnabled),
            ),
            ProfileSettingRow(
              title: 'Test reminders',
              subtitle: 'Reminders when it is time to take a test',
              trailing: Switch(
                value: state.testRemindersEnabled,
                onChanged: state.notificationsEnabled ? notifier.setTestRemindersEnabled : null,
              ),
            ),
            ProfileSettingRow(
              title: 'Result reminders',
              subtitle: 'Reminders to record and review your result',
              trailing: Switch(
                value: state.resultRemindersEnabled,
                onChanged: state.notificationsEnabled ? notifier.setResultRemindersEnabled : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ProfileSectionCard(
          children: [
            ProfileSettingRow(
              title: 'Device notification settings',
              subtitle: 'Manage permissions in system settings',
              trailing: const Icon(Icons.open_in_new, color: Color(0xFF68686B), size: 19),
              onPressed: () => unawaited(ref.read(notificationPermissionServiceProvider).openAppSettings()),
            ),
          ],
        ),
      ],
    );
  }
}
