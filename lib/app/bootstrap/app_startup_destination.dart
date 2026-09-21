// 在 runApp 前仅使用本地认证数据计算 Flutter 首屏路由。
// 网络刷新和运行期 Session 生命周期仍由 AuthSessionNotifier 负责。

import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/auth/token_storage.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/repositories/welcome_completion_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 根据本地 Token、用户快照和 Welcome 状态确定冷启动首屏。
Future<String> resolveAppStartupLocation(
  SharedPreferences preferences,
) async {
  try {
    final token = await PreferencesTokenStorage(preferences).read();
    if (token == null ||
        !token.expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      return AuthEntryPage.path;
    }

    final userStorage = PreferencesCurrentUserStorage(preferences);
    try {
      final user = await userStorage.read();
      if (user == null) return AuthEntryPage.path;

      if (!user.isProfileCompleted) {
        return AccountProfilePage.location(user.email ?? '', user.id);
      }

      final welcomeRepository = WelcomeCompletionRepository(preferences);
      return welcomeRepository.isCompleted(user.id)
          ? HomePage.path
          : OnboardingWelcomePage.location(user.fullName ?? '', user.id);
    } finally {
      userStorage.dispose();
    }
  } catch (_) {
    // 本地启动数据异常时安全降级到登录入口，避免停留在无业务内容的中间页。
    return AuthEntryPage.path;
  }
}
