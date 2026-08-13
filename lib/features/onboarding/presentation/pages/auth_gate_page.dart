// 应用冷启动认证门，根据本地 App Session 决定进入认证入口或首页。
// 资料和欢迎流程的服务端状态确定后，在此补充分流节点。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/features/auth/auth_session_provider.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';

/// 监听认证 Session，并在冷启动后执行一次无动画分流。
class AuthGatePage extends ConsumerWidget {
  const AuthGatePage({super.key});

  static const path = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    session.whenData((value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        // TODO: <pf> 服务端返回资料和欢迎完成状态后补充分流。
        context.go(
          value.status == AuthSessionStatus.authenticated
              ? HomePage.path
              : AuthEntryPage.path,
        );
      });
    });
    return const Scaffold(
      backgroundColor: Color(0xFFEDE8E0),
      body: SizedBox.expand(),
    );
  }
}
