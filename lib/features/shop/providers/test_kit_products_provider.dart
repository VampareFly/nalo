import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/shop/models/test_kit_product.dart';

final testKitProductsProvider = Provider<List<TestKitProduct>>((ref) {
  // TODO: <pf> Replace Shopify preview URLs with stable storefront product URLs before release.
  return const [
    TestKitProduct(
      id: 'cortisol',
      icon: '🌿',
      name: 'Cortisol Test',
      description: '3-strip pack · ng/mL · Stress & energy insights',
      price: r'$15',
      subscriptionPrice: r'$13.50 with sub',
      productUrl:
          'https://test-store-001-55rykspg.myshopify.com/products/test001-%E5%95%86%E5%93%81-%E6%A0%87%E9%A2%98?app_token=test_ppf_123',
    ),
    TestKitProduct(
      id: 'testosterone',
      icon: '⚡',
      name: 'Testosterone Test',
      description: '3-strip pack · ng/dL · Energy & drive insights',
      price: r'$18',
      subscriptionPrice: r'$16.20 with sub',
      productUrl:
          'https://test-store-001-55rykspg.myshopify.com/products/test001-%E5%95%86%E5%93%81-%E6%A0%87%E9%A2%98?app_token=test_ppf_123',
    ),
  ];
});
