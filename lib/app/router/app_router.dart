// 集中维护应用路由，并为已定义 Page Name 的页面提供路由曝光。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/home/presentation/pages/test_history_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_gate_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/profile/presentation/pages/profile_page.dart';
import 'package:nalo/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:nalo/features/shop/presentation/pages/guest_kit_shop_page.dart';
import 'package:nalo/features/test_flow/presentation/pages/test_flow_page.dart';

/// 提供全局弹窗和根导航共用的 Navigator Key。
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 向页面暴露实际路由层级变化，用于判断业务页面是否位于顶层。
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();

/// 集中维护应用路由和页面跳转配置。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [
      ref.watch(analyticsNavigatorObserverProvider),
      appRouteObserver,
    ],
    initialLocation: AuthGatePage.path,
    routes: [
      GoRoute(
        path: AuthGatePage.path,
        builder: (context, state) => const AuthGatePage(),
      ),
      GoRoute(
        path: HomePage.path,
        pageBuilder: (context, state) => NoTransitionPage(
          key: ValueKey(state.uri),
          child: HomePage(
            initialIndex: state.uri.queryParameters['tab'] == 'shop' ? 1 : 0,
          ),
        ),
      ),
      GoRoute(
        name: AnalyticsPageName.testHistory.value,
        path: TestHistoryPage.path,
        builder: (context, state) => const TestHistoryPage(),
      ),
      GoRoute(
        name: AnalyticsPageName.profile.value,
        path: ProfilePage.path,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        name: AnalyticsPageName.profileEdit.value,
        path: EditProfilePage.path,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        name: AnalyticsPageName.loginSignIn.value,
        path: AuthEntryPage.path,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AuthEntryPage()),
      ),
      GoRoute(
        name: AnalyticsPageName.shop.value,
        path: GuestKitShopPage.path,
        builder: (context, state) => const GuestKitShopPage(),
      ),
      GoRoute(
        name: AnalyticsPageName.createAccount.value,
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
        name: AnalyticsPageName.welcome.value,
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
