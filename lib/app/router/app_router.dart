import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/home/presentation/pages/test_history_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_gate_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/profile/presentation/pages/profile_page.dart';
import 'package:nalo/features/profile/presentation/pages/about_page.dart';
import 'package:nalo/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:nalo/features/profile/presentation/pages/help_faq_page.dart';
import 'package:nalo/features/profile/presentation/pages/privacy_data_page.dart';
import 'package:nalo/features/profile/presentation/pages/profile_notifications_page.dart';
import 'package:nalo/features/test_flow/presentation/pages/test_flow_page.dart';

/// 提供全局弹窗和根导航共用的 Navigator Key。
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 集中维护应用路由和页面跳转配置。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AuthGatePage.path,
    routes: [
      GoRoute(
        path: AuthGatePage.path,
        builder: (context, state) => const AuthGatePage(),
      ),
      GoRoute(
        path: HomePage.path,
        pageBuilder: (context, state) => NoTransitionPage(
          child: HomePage(
            initialIndex: state.uri.queryParameters['tab'] == 'shop' ? 1 : 0,
          ),
        ),
      ),
      GoRoute(
        path: TestHistoryPage.path,
        builder: (context, state) => const TestHistoryPage(),
      ),
      GoRoute(
        path: ProfilePage.path,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: EditProfilePage.path,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: ProfileNotificationsPage.path,
        builder: (context, state) => const ProfileNotificationsPage(),
      ),
      GoRoute(
        path: HelpFaqPage.path,
        builder: (context, state) => const HelpFaqPage(),
      ),
      GoRoute(
        path: PrivacyDataPage.path,
        builder: (context, state) => const PrivacyDataPage(),
      ),
      GoRoute(
        path: AboutPage.path,
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: AuthEntryPage.path,
        builder: (context, state) => const AuthEntryPage(),
      ),
      GoRoute(
        path: AccountProfilePage.path,
        builder: (context, state) => AccountProfilePage(
          email: state.uri.queryParameters['email'] ?? '',
          userId: int.tryParse(state.uri.queryParameters['userId'] ?? '') ?? -1,
          completionDestination:
              state.uri.queryParameters['destination'] == 'shop'
              ? OnboardingCompletionDestination.shop
              : OnboardingCompletionDestination.home,
        ),
      ),
      GoRoute(
        path: OnboardingWelcomePage.path,
        pageBuilder: (context, state) => NoTransitionPage(
          child: OnboardingWelcomePage(
            fullName: state.uri.queryParameters['name'] ?? '',
            userId:
                int.tryParse(state.uri.queryParameters['userId'] ?? '') ?? -1,
            completionDestination:
                state.uri.queryParameters['destination'] == 'shop'
                ? OnboardingCompletionDestination.shop
                : OnboardingCompletionDestination.home,
          ),
        ),
      ),
      GoRoute(
        path: TestFlowPage.path,
        builder: (context, state) => const TestFlowPage(),
      ),
    ],
  );
});
