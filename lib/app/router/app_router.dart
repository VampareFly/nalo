import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/features/home/presentation/pages/home_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/get_started_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/kit_question_page.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/launch_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // TODO: <pf> Restore LaunchPage.path after onboarding development is complete.
    initialLocation: GetStartedPage.path,
    routes: [
      GoRoute(
        path: LaunchPage.path,
        builder: (context, state) => const LaunchPage(),
      ),
      GoRoute(
        path: HomePage.path,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: GetStartedPage.path,
        builder: (context, state) => const GetStartedPage(),
      ),
      GoRoute(
        path: KitQuestionPage.path,
        builder: (context, state) => const KitQuestionPage(),
      ),
    ],
  );
});
