import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tester_kit/features/home/presentation/pages/home_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: HomePage.path,
    routes: [
      GoRoute(
        path: HomePage.path,
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});
