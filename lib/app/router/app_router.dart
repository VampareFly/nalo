import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/full_tend/presentation/pages/full_tend_page.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/notifications/presentation/pages/notification_permission_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_gate_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/profile/presentation/pages/profile_page.dart';
import 'package:nalo/features/profile/presentation/pages/about_page.dart';
import 'package:nalo/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:nalo/features/profile/presentation/pages/help_faq_page.dart';
import 'package:nalo/features/profile/presentation/pages/privacy_data_page.dart';
import 'package:nalo/features/profile/presentation/pages/profile_notifications_page.dart';
import 'package:nalo/features/shop/presentation/pages/subscription_details_page.dart';
import 'package:nalo/features/test_flow/presentation/pages/test_flow_page.dart';

/// 集中维护应用路由和页面跳转配置。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AuthGatePage.path,
    routes: [
      GoRoute(path: AuthGatePage.path, builder: (context, state) => const AuthGatePage()),
      GoRoute(
        path: HomePage.path,
        pageBuilder: (context, state) => NoTransitionPage(
          child: HomePage(initialIndex: state.uri.queryParameters['tab'] == 'shop' ? 1 : 0),
        ),
      ),
      GoRoute(path: FullTendPage.path, builder: (context, state) => const FullTendPage()),
      GoRoute(
        path: SubscriptionDetailsPage.path,
        builder: (context, state) => const SubscriptionDetailsPage(),
      ),
      GoRoute(path: ProfilePage.path, builder: (context, state) => const ProfilePage()),
      GoRoute(path: EditProfilePage.path, builder: (context, state) => const EditProfilePage()),
      GoRoute(path: ProfileNotificationsPage.path, builder: (context, state) => const ProfileNotificationsPage()),
      GoRoute(path: HelpFaqPage.path, builder: (context, state) => const HelpFaqPage()),
      GoRoute(path: PrivacyDataPage.path, builder: (context, state) => const PrivacyDataPage()),
      GoRoute(path: AboutPage.path, builder: (context, state) => const AboutPage()),
      GoRoute(
        path: NotificationPermissionPage.path,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: NotificationPermissionPage(),
        ),
      ),
      GoRoute(path: AuthEntryPage.path, builder: (context, state) => const AuthEntryPage()),
      GoRoute(
        path: AccountProfilePage.path,
        builder: (context, state) => AccountProfilePage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: OnboardingWelcomePage.path,
        pageBuilder: (context, state) => NoTransitionPage(
          child: OnboardingWelcomePage(
            fullName: state.uri.queryParameters['name'] ?? '',
          ),
        ),
      ),
      GoRoute(path: TestFlowPage.path, builder: (context, state) => const TestFlowPage()),
    ],
  );
});
