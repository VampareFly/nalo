import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/notifications/services/notification_permission_service.dart';

final notificationPermissionServiceProvider = Provider<NotificationPermissionService>((ref) {
  return PlatformNotificationPermissionService();
});

final notificationPermissionStatusProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(notificationPermissionServiceProvider).isNotificationPermissionEnabled();
});
