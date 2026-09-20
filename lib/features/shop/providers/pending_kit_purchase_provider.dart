// 保存从未登录商品列表发起、跨 Shopify 登录和资料完善页面继续执行的购买意图。
// 页面只保存商品并消费一次购买链接；正常登录后的 App 页面分流不由本状态决定。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';
import 'package:nalo/features/shop/view_models/shop_view_model.dart';

/// 管理当前待完成的单个 Kit 购买意图。
class PendingKitPurchaseNotifier extends Notifier<TestKitProduct?> {
  bool _isCreatingLink = false;

  @override
  TestKitProduct? build() => null;

  /// 用户在未登录商品列表点击 Get kit 时覆盖当前待购买商品。
  void select(TestKitProduct product) => state = product;

  /// 放弃当前购买流程时清除临时商品。
  void clear() => state = null;

  /// 登录及必要的资料完善完成后，生成一次购买链接并消费本次购买意图。
  Future<ShopPurchaseResult?> createPurchaseLink() async {
    final product = state;
    if (product == null || _isCreatingLink) return null;
    _isCreatingLink = true;
    try {
      final result = await ref
          .read(shopViewModelProvider.notifier)
          .createPurchaseLink(product, pageName: AnalyticsPageName.shop);
      return result;
    } finally {
      if (state == product) state = null;
      _isCreatingLink = false;
    }
  }
}

/// 提供跨商品列表、登录和资料完善页面共享的临时购买状态。
final pendingKitPurchaseProvider =
    NotifierProvider<PendingKitPurchaseNotifier, TestKitProduct?>(
      PendingKitPurchaseNotifier.new,
    );
