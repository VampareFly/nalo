import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/app/config/app_config_repository.dart';
import 'package:tester_kit/core/storage/shared_preferences_provider.dart';

/// 注入应用配置仓库。
final appConfigRepositoryProvider = FutureProvider<AppConfigRepository>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return AppConfigRepository(preferences);
});
