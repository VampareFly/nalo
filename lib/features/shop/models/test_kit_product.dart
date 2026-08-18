// Shop 商品、分页和购买链接的业务模型。
// Service 负责解析协议，ViewModel 将本文件的模型交给 Shop 页展示。

import 'package:flutter/foundation.dart';
import 'package:nalo/core/network/api_client.dart';

/// 商店页展示和生成购买链接所需的商品数据。
@immutable
class TestKitProduct {
  const TestKitProduct({
    required this.productId,
    required this.variantId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.compareAtPrice,
    required this.currency,
  });

  final int productId;
  final int variantId;
  final String title;
  final String? description;
  final String? imageUrl;
  final String price;
  final String? compareAtPrice;
  final String currency;

  /// 从商品列表的单条 JSON 中创建商品。
  factory TestKitProduct.fromJson(Map<String, dynamic> json) {
    return TestKitProduct(
      productId: _requiredInt(json, 'product_id'),
      variantId: _requiredInt(json, 'variant_id'),
      title: _requiredString(json, 'title'),
      description: _nullableString(json, 'description'),
      imageUrl: _nullableString(json, 'image_url'),
      price: _requiredString(json, 'price'),
      compareAtPrice: _nullableString(json, 'compare_at_price'),
      currency: _requiredString(json, 'currency'),
    );
  }
}

/// 商品列表的单页结果及后续分页标记。
@immutable
class TestKitProductPage {
  const TestKitProductPage({
    required this.products,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  final List<TestKitProduct> products;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  /// 从商品列表接口的 data 对象中创建分页结果。
  factory TestKitProductPage.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    final rawPagination = json['pagination'];
    if (rawProducts is! List || rawPagination is! Map<String, dynamic>) {
      throw const ResponseFormatException(
        'The products response is missing products or pagination.',
      );
    }
    final page = _requiredInt(rawPagination, 'page');
    final pageSize = _requiredInt(rawPagination, 'page_size');
    final total = _requiredInt(rawPagination, 'total');
    final hasMore = rawPagination['has_more'];
    if (hasMore is! bool) {
      throw const ResponseFormatException(
        'The pagination field has_more is not a boolean.',
      );
    }
    return TestKitProductPage(
      products: rawProducts.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const ResponseFormatException(
            'A product in the response is not an object.',
          );
        }
        return TestKitProduct.fromJson(item);
      }).toList(growable: false),
      page: page,
      pageSize: pageSize,
      total: total,
      hasMore: hasMore,
    );
  }
}

/// 服务端生成的短期 Shopify 购买链接。
@immutable
class ShopifyProductLink {
  const ShopifyProductLink({required this.url, required this.expiresAt});

  final Uri url;
  final DateTime expiresAt;

  /// 解析购买 URL，并将服务端秒级时间戳转为 DateTime。
  factory ShopifyProductLink.fromJson(Map<String, dynamic> json) {
    final rawUrl = _requiredString(json, 'product_url');
    final expiresAt = _requiredInt(json, 'expires_at');
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const ResponseFormatException(
        'The Shopify product URL is not a valid HTTPS URL.',
      );
    }
    return ShopifyProductLink(
      url: uri,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw ResponseFormatException('The product field $key is not an integer.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ResponseFormatException('The product field $key is not a string.');
  }
  return value.trim();
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw ResponseFormatException('The product field $key is not a string.');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
