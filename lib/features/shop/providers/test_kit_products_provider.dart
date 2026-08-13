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
      productUrl: 'https://2a79p6eko31a130p-69330108529.shopifypreview.com/products_preview?preview_key=e589a4f3928c0fe609048fa2f5963e4c',
    ),
    TestKitProduct(
      id: 'testosterone',
      icon: '⚡',
      name: 'Testosterone Test',
      description: '3-strip pack · ng/dL · Energy & drive insights',
      price: r'$18',
      subscriptionPrice: r'$16.20 with sub',
      productUrl: 'https://u72lx5stzy1eb9j2-69330108529.shopifypreview.com/products_preview?preview_key=fa06256ff40c577b38a0b4862e3faae7',
    ),
  ];
});
