import 'package:flutter/foundation.dart';

@immutable
class TestKitProduct {
  const TestKitProduct({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.price,
    required this.subscriptionPrice,
  });

  final String id;
  final String icon;
  final String name;
  final String description;
  final String price;
  final String subscriptionPrice;
}
