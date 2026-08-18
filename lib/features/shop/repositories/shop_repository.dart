// 组装 ShopService，为 ViewModel 提供稳定的商品与购买链接能力。
// Provider 在此完成 ApiClient 依赖注入，页面不感知网络实现。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';
import 'package:nalo/features/shop/services/shop_service.dart';

/// 编排 Shop 数据获取，并隔离 ViewModel 与网络 Service。
class ShopRepository {
  const ShopRepository(this._service);

  final ShopService _service;

  /// 获取一页商品数据。
  Future<TestKitProductPage> getProducts({
    required int page,
    int pageSize = 10,
  }) => _service.getProducts(page: page, pageSize: pageSize);

  /// 为用户当前点击的商品生成临时购买链接。
  Future<ShopifyProductLink> createPurchaseLink(TestKitProduct product) =>
      _service.createShopifyUrl(
        productId: product.productId,
        variantId: product.variantId,
      );
}

/// 注入 Shop Repository 及其使用的业务 ApiClient。
final shopRepositoryProvider = FutureProvider<ShopRepository>((ref) async {
  final apiClient = await ref.watch(businessApiClientProvider.future);
  return ShopRepository(ShopService(apiClient));
});
