import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/shop/models/test_kit_product.dart';

final testKitProductsProvider = Provider<List<TestKitProduct>>((ref) {
  return const [
    TestKitProduct(
      id: 'cortisol',
      icon: '🌿',
      name: 'Cortisol Test',
      description: '3-strip pack · ng/mL · Stress & energy insights',
      price: r'$15',
      subscriptionPrice: r'$13.50 with sub',
    ),
    TestKitProduct(
      id: 'testosterone',
      icon: '⚡',
      name: 'Testosterone Test',
      description: '3-strip pack · ng/dL · Energy & drive insights',
      price: r'$18',
      subscriptionPrice: r'$16.20 with sub',
    ),
  ];
});
