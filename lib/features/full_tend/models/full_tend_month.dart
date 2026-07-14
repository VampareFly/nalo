import 'package:flutter/foundation.dart';

enum FullTendRangeStatus { normal, high }

@immutable
class FullTendReading {
  const FullTendReading({
    required this.value,
    required this.testedAt,
    required this.periodLabel,
    required this.status,
  });

  final double value;
  final DateTime testedAt;
  final String periodLabel;
  final FullTendRangeStatus status;
}

@immutable
class FullTendMonth {
  FullTendMonth({
    required this.month,
    required List<FullTendReading> readings,
  }) : readings = List.unmodifiable(_normalizeReadings(readings));

  static const maximumReadings = 3;

  final DateTime month;
  final List<FullTendReading> readings;

  int get completedCount => readings.length;
  int get remainingCount => maximumReadings - completedCount;
  bool get isComplete => completedCount == maximumReadings;

  double? get average {
    if (readings.isEmpty) return null;
    return readings.fold<double>(0, (sum, reading) => sum + reading.value) / readings.length;
  }

  bool get hasTimingWarning {
    if (readings.length < 2) return false;

    final minutes = readings.map((reading) => reading.testedAt.hour * 60 + reading.testedAt.minute).toList();
    for (var first = 0; first < minutes.length - 1; first++) {
      for (var second = first + 1; second < minutes.length; second++) {
        if ((minutes[first] - minutes[second]).abs() > const Duration(hours: 2).inMinutes) {
          return true;
        }
      }
    }
    return false;
  }

  static List<FullTendReading> _normalizeReadings(List<FullTendReading> readings) {
    final sorted = [...readings]..sort((first, second) => first.testedAt.compareTo(second.testedAt));
    return sorted.take(maximumReadings).toList();
  }
}
