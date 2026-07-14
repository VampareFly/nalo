import 'package:flutter_test/flutter_test.dart';
import 'package:tester_kit/features/full_tend/models/full_tend_month.dart';

void main() {
  FullTendReading reading(int day, int hour, {double value = 6}) => FullTendReading(
    value: value,
    testedAt: DateTime(2026, 7, day, hour),
    periodLabel: 'Morning',
    status: FullTendRangeStatus.normal,
  );

  test('sorts readings and calculates monthly progress and average', () {
    final month = FullTendMonth(month: DateTime(2026, 7), readings: [reading(5, 8, value: 6), reading(3, 8, value: 8)]);

    expect(month.readings.first.testedAt.day, 3);
    expect(month.completedCount, 2);
    expect(month.remainingCount, 1);
    expect(month.average, 7);
    expect(month.isComplete, isFalse);
  });

  test('shows timing warning when any pair differs by more than two hours', () {
    final month = FullTendMonth(month: DateTime(2026, 7), readings: [reading(1, 8), reading(3, 10), reading(5, 11)]);

    expect(month.hasTimingWarning, isTrue);
  });

  test('does not show timing warning when all times are within two hours', () {
    final month = FullTendMonth(month: DateTime(2026, 7), readings: [reading(1, 8), reading(3, 9), reading(5, 10)]);

    expect(month.hasTimingWarning, isFalse);
  });

  test('keeps at most three readings for one month', () {
    final month = FullTendMonth(
      month: DateTime(2026, 7),
      readings: [reading(1, 8), reading(3, 8), reading(5, 8), reading(7, 8)],
    );

    expect(month.readings, hasLength(FullTendMonth.maximumReadings));
    expect(month.isComplete, isTrue);
  });
}
