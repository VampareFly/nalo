import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nalo/app/router/app_router.dart';
import 'package:nalo/app/config/app_environment.dart';
import 'package:nalo/app/config/environment_picker_dialog.dart';
import 'package:nalo/app/theme/app_theme.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/core/device/shake_detector.dart';
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
  late final ShakeDetector _shakeDetector;
  bool _environmentDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _configureGlobalLoading();
    WidgetsBinding.instance.addObserver(this);
    _authSessionSubscription = ref.listenManual(
      authSessionProvider,
      _handleAuthSessionChange,
      fireImmediately: true,
    );
    _shakeDetector = ShakeDetector()..start(onShake: _showEnvironmentPicker);
  }

  /// 统一使用 Shop 页面相同的蓝色圆形进度动画。
  void _configureGlobalLoading() {
    EasyLoading.instance
      ..loadingStyle = EasyLoadingStyle.custom
      ..maskType = EasyLoadingMaskType.custom
      ..maskColor = const Color(0x66000000)
      ..userInteractions = false
      ..dismissOnTap = false
      ..backgroundColor = Colors.transparent
      ..indicatorColor = const Color(0xFF008BC7)
      ..progressColor = const Color(0xFF008BC7)
      ..textColor = const Color(0xFF1A2433)
      ..boxShadow = const []
      ..contentPadding = EdgeInsets.zero
      ..indicatorWidget = const SizedBox.square(
        dimension: 36,
        child: CircularProgressIndicator(color: Color(0xFF008BC7)),
      );
  }

  @override
  void dispose() {
    _authSessionSubscription.close();
    unawaited(_shakeDetector.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 在所有构建模式中选择环境；保存后退出 App，重启时统一初始化相关服务。
  Future<void> _showEnvironmentPicker() async {
    if (_environmentDialogVisible || !mounted) return;
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) return;
    _environmentDialogVisible = true;
    final current =
        ref.read(appEnvironmentProvider).value ?? defaultEnvironment;
    AppEnvironment? selected;
    try {
      selected = await showDialog<AppEnvironment>(
        context: navigatorContext,
        builder: (_) => EnvironmentPickerDialog(current: current),
      );
    } finally {
      _environmentDialogVisible = false;
    }
    if (!mounted || selected == null || selected == current) return;
    await ref.read(authSessionProvider.notifier).logout();
    await ref.read(appEnvironmentProvider.notifier).setEnvironment(selected);
    exit(0);
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

  /// 处理 Session 状态变化；每次失效事件均尝试弹窗，显示中的弹窗不会叠加。
  void _handleAuthSessionChange(
    AsyncValue<AuthSessionState>? previous,
    AsyncValue<AuthSessionState> next,
  ) {
    final previousStatus = previous?.value?.status;
    final nextStatus = next.value?.status;
    if (nextStatus == AuthSessionStatus.sessionExpired) {
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
