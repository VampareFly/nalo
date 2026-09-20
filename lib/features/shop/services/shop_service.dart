// 封装 Shop 商品列表和 Shopify 购买链接接口。
// 该层只处理请求参数与 DTO 解析，不管理页面状态或外部跳转。

import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';

/// 调用 Nalo Shop 接口并返回已解析的业务模型。
class ShopService {
  const ShopService(this._apiClient);

  final ApiClient _apiClient;

  /// 匿名获取指定页商品，供登录前 Kit 列表和登录后 Shop Tab 复用。
  Future<TestKitProductPage> getProducts({
    required int page,
    required int pageSize,
    String? detectionType,
  }) async {
    final result = await _apiClient.get<TestKitProductPage>(
      '/api/v1/app/products',
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (detectionType != null) 'detection_type': detectionType,
      },
      decoder: _decodeProductPage,
      requiresAuth: false,
    );
    if (result == null) {
      throw const ResponseFormatException('The products response is empty.');
    }
    return result;
  }

  /// 根据商品与规格 ID 生成本次购买使用的 Shopify URL。
  Future<ShopifyProductLink> createShopifyUrl({
    required int productId,
    required int variantId,
  }) async {
    final result = await _apiClient.post<ShopifyProductLink>(
      '/api/v1/app/products/shopify-url',
      data: {'product_id': productId, 'variant_id': variantId},
      decoder: _decodeProductLink,
    );
    if (result == null) {
      throw const ResponseFormatException(
        'The Shopify product URL response is empty.',
      );
    }
    return result;
  }

  TestKitProductPage _decodeProductPage(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException('The products data is not an object.');
    }
    return TestKitProductPage.fromJson(data);
  }

  ShopifyProductLink _decodeProductLink(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ResponseFormatException(
        'The Shopify product URL data is not an object.',
      );
    }
    return ShopifyProductLink.fromJson(data);
  }
}
