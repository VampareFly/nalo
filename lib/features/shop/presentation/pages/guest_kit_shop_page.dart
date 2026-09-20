// 展示登录前可访问的 Kit 商品列表，不包含首页 Tab 和个人中心入口。
// Get kit 先建立 Shopify Session，随后保持正常 App 分流并打开所选商品详情。

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/widgets/nalo_back_button.dart';
import 'package:nalo/features/home/presentation/pages/home_page.dart';
import 'package:nalo/features/onboarding/models/onboarding_auth_result.dart';
import 'package:nalo/features/onboarding/presentation/pages/account_profile_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/auth_entry_page.dart';
import 'package:nalo/features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import 'package:nalo/features/onboarding/services/shopify_backend_auth_service.dart';
import 'package:nalo/features/onboarding/view_models/auth_entry_view_model.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';
import 'package:nalo/features/shop/presentation/pages/shop_page.dart';
import 'package:nalo/features/shop/providers/pending_kit_purchase_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// 登录注册入口下的独立 Kit 商品列表页。
class GuestKitShopPage extends ConsumerStatefulWidget {
  const GuestKitShopPage({super.key});

  static const path = '/kit-shop';

  @override
  ConsumerState<GuestKitShopPage> createState() => _GuestKitShopPageState();
}

class _GuestKitShopPageState extends ConsumerState<GuestKitShopPage> {
  Future<void> _getKit(TestKitProduct product) async {
    ref.read(pendingKitPurchaseProvider.notifier).select(product);
    EasyLoading.show();
    final result = await ref
        .read(authEntryViewModelProvider.notifier)
        .authorize(
          ShopifyAuthIntent.kitPurchase,
          pageName: AnalyticsPageName.shop,
        );
    EasyLoading.dismiss();
    if (!mounted) return;
    if (result == null) {
      final message = ref.read(authEntryViewModelProvider).errorMessage;
      if (message != null) {
        BotToast.showText(text: message, align: Alignment.center);
      }
      return;
    }
    if (result.destination == OnboardingAuthDestination.accountProfile) {
      context.go(
        AccountProfilePage.location(result.email ?? '', result.userId),
      );
      return;
    }
    await _openProductAndContinue(result);
  }

  Future<void> _openProductAndContinue(OnboardingAuthResult authResult) async {
    EasyLoading.show();
    final purchaseResult = await ref
        .read(pendingKitPurchaseProvider.notifier)
        .createPurchaseLink();
    EasyLoading.dismiss();
    if (!mounted) return;

    switch (authResult.destination) {
      case OnboardingAuthDestination.welcome:
        context.go(
          OnboardingWelcomePage.location(
            authResult.fullName ?? '',
            authResult.userId,
          ),
        );
        break;
      case OnboardingAuthDestination.home:
      case OnboardingAuthDestination.shop:
        context.go(HomePage.path);
        break;
      case OnboardingAuthDestination.accountProfile:
        return;
    }

    final uri = purchaseResult?.url;
    if (uri == null) {
      final message = purchaseResult?.errorMessage;
      if (message != null) {
        BotToast.showText(text: message, align: Alignment.center);
      }
      return;
    }
    final didOpen = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!didOpen) {
      BotToast.showText(
        text: 'Unable to open the shop.',
        align: Alignment.center,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authEntryViewModelProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFEDE8E0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEDE8E0),
        surfaceTintColor: Colors.transparent,
        leadingWidth: 58,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: NaloBackButton(
            onPressed: () {
              ref.read(pendingKitPurchaseProvider.notifier).clear();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AuthEntryPage.path);
              }
            },
          ),
        ),
        title: const Text(
          'Shop',
          style: TextStyle(
            color: Color(0xFF1A2433),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: ShopPage(
        isActive: true,
        exposureCycle: 0,
        onMinePressed: () {},
        showTopBar: false,
        showReferral: false,
        analyticsPageName: AnalyticsPageName.shop,
        onPurchaseRequested: _getKit,
      ),
    );
  }
}
