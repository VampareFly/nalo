import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nalo/app/router/app_router.dart';
import 'package:nalo/app/theme/app_theme.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/test_flow/providers/test_flow_provider.dart';
import 'package:nalo/l10n/generated/app_localizations.dart';

/// 应用根 Widget，组装主题、路由、国际化和全局 UI 服务。
class NaloApp extends ConsumerStatefulWidget {
  const NaloApp({super.key});

  @override
  ConsumerState<NaloApp> createState() => _NaloAppState();
}

/// 监听应用生命周期，并维护全局 Session 与通知权限状态。
class _NaloAppState extends ConsumerState<NaloApp> with WidgetsBindingObserver {
  bool _isSessionExpiredDialogVisible = false;
  late final ProviderSubscription<AsyncValue<AuthSessionState>>
  _authSessionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSessionSubscription = ref.listenManual(
      authSessionProvider,
      _handleAuthSessionChange,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _authSessionSubscription.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appNotificationPermissionProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.watch(appNotificationPermissionProvider);
    ref.listen(sessionExpirationStreamProvider, (_, next) {
      if (next.hasValue) {
        ref.read(authSessionProvider.notifier).markExpired(next.requireValue);
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

  /// 同时覆盖冷启动已恢复的 Session 与运行期间新登录成功两种配置加载时机。
  void _handleAuthSessionChange(
    AsyncValue<AuthSessionState>? previous,
    AsyncValue<AuthSessionState> next,
  ) {
    final previousStatus = previous?.value?.status;
    final nextStatus = next.value?.status;
    if (nextStatus == AuthSessionStatus.sessionExpired &&
        previousStatus != AuthSessionStatus.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSessionExpiredDialog(
          next.value?.expirationMessage ??
              'Your login has expired. Please log in again.',
        );
      });
    }
    if (nextStatus == AuthSessionStatus.authenticated &&
        previousStatus != AuthSessionStatus.authenticated) {
      unawaited(ref.read(testFlowProvider.notifier).initializeConfig());
    }
  }

  Future<void> _showSessionExpiredDialog(String message) async {
    if (_isSessionExpiredDialogVisible) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSessionExpiredDialog(message);
      });
      return;
    }
    final content = message.trim().isEmpty
        ? 'Your login has expired. Please log in again.'
        : message;
    _isSessionExpiredDialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Login expired'),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(appRouterProvider).go(AuthEntryPage.path);
              },
              child: const Text('Log in again'),
            ),
          ],
        ),
      ),
    );
    _isSessionExpiredDialogVisible = false;
  }

  void greet({required String name}) {
    test(name: 'hello world');
    print(name);
  }

  void test({required String name}) {
    print(name);
  }
}
