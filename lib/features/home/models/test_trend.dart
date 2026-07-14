import 'package:flutter/foundation.dart';

@immutable
class TrendPoint {
  const TrendPoint({required this.label, required this.value});

  final String label;
  final double value;
}

@immutable
class TestTrend {
  const TestTrend({
    required this.label,
    required this.title,
    required this.referenceLabel,
    required this.minimumValue,
    required this.maximumValue,
    required this.averageLabel,
    required this.averageValue,
    required this.points,
  });

  final String label;
  final String title;
  final String referenceLabel;
  final double minimumValue;
  final double maximumValue;
  final String averageLabel;
  final String averageValue;
  final List<TrendPoint> points;
}
