import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/home/models/test_trend.dart';

final testTrendsProvider = Provider<List<TestTrend>>((ref) {
  return const [
    TestTrend(
      label: 'Cortisol',
      title: 'Cortisol trend',
      referenceLabel: 'SHADED BAND = MORNING REFERENCE (1.0–7.5 NG/ML)',
      minimumValue: 0,
      maximumValue: 8,
      averageLabel: 'Cortisol avg',
      averageValue: '7.1 ng/mL',
      points: [TrendPoint(label: 'Jul 3', value: 7.8), TrendPoint(label: 'Jul 5', value: 6.4)],
    ),
    TestTrend(
      label: 'Testosterone',
      title: 'Testosterone trend',
      referenceLabel: 'SHADED BAND = MORNING REFERENCE (300–900 NG/DL)',
      minimumValue: 0,
      maximumValue: 1000,
      averageLabel: 'Testosterone avg',
      averageValue: '540 ng/dL',
      points: [TrendPoint(label: 'Jul 3', value: 520), TrendPoint(label: 'Jul 5', value: 560)],
    ),
  ];
});
