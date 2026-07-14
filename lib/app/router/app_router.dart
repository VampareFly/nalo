import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/features/full_tend/presentation/pages/full_tend_page.dart';
import 'package:tester_kit/features/home/presentation/pages/home_page.dart';
import 'package:tester_kit/features/notifications/presentation/pages/notification_permission_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/login_method_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/login_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/get_started_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/kit_question_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/launch_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/register_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // TODO: <pf> Restore LaunchPage.path after onboarding development is complete.
    initialLocation: GetStartedPage.path,
    routes: [
      GoRoute(path: LaunchPage.path, builder: (context, state) => const LaunchPage()),
      GoRoute(
        path: HomePage.path,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomePage(),
        ),
      ),
      GoRoute(path: FullTendPage.path, builder: (context, state) => const FullTendPage()),
      GoRoute(
        path: NotificationPermissionPage.path,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: NotificationPermissionPage(),
        ),
      ),
      GoRoute(path: GetStartedPage.path, builder: (context, state) => const GetStartedPage()),
      GoRoute(path: KitQuestionPage.path, builder: (context, state) => const KitQuestionPage()),
      GoRoute(path: LoginMethodPage.path, builder: (context, state) => const LoginMethodPage()),
      GoRoute(path: LoginPage.path, builder: (context, state) => const LoginPage()),
      GoRoute(path: RegisterPage.path, builder: (context, state) => const RegisterPage()),
    ],
  );
});
