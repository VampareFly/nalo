import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tester_kit/app/router/app_router.dart';
import 'package:tester_kit/app/theme/app_theme.dart';
import 'package:tester_kit/core/network/api_providers.dart';
import 'package:tester_kit/features/auth/auth_session_provider.dart';
import 'package:tester_kit/features/onboarding/presentation/pages/login_page.dart';
import 'package:tester_kit/l10n/generated/app_localizations.dart';

/// 应用根 Widget，组装主题、路由、国际化和全局 UI 服务。
class TesterKitApp extends ConsumerWidget {
  const TesterKitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(authSessionProvider);
    ref.listen(sessionExpirationStreamProvider, (_, next) {
      if (next.hasValue) {
        ref.read(authSessionProvider.notifier).markExpired();
      }
    });
    ref.listen(authSessionProvider, (previous, next) {
      final previousStatus = previous?.value?.status;
      final nextStatus = next.value?.status;
      if (nextStatus == AuthSessionStatus.sessionExpired &&
          previousStatus != AuthSessionStatus.sessionExpired) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          BotToast.showText(
            text: 'Your session has expired. Please log in again.',
            align: Alignment.center,
          );
          router.go(LoginPage.path);
        });
      }
    });

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp.router(
        title: 'Nalo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: EasyLoading.init(builder: BotToastInit()),
      ),
    );
  }

  void greet({required String name}) {
    test(name: 'hello world');
    print(name);
  }

  void test({required String name}) {
    print(name);
  }
}
