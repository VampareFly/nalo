import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/full_tend/models/full_tend_month.dart';

final fullTendMonthsProvider = Provider<List<FullTendMonth>>((ref) {
  return [
    FullTendMonth(
      month: DateTime(2026, 7),
      readings: [
        FullTendReading(
          value: 7.8,
          testedAt: DateTime(2026, 7, 3, 8, 2),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.high,
        ),
        FullTendReading(
          value: 6.4,
          testedAt: DateTime(2026, 7, 5, 11, 31),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
      ],
    ),
    FullTendMonth(
      month: DateTime(2026, 6),
      readings: [
        FullTendReading(
          value: 7.8,
          testedAt: DateTime(2026, 6, 25, 8, 2),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.high,
        ),
        FullTendReading(
          value: 6.4,
          testedAt: DateTime(2026, 6, 27, 7, 31),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
        FullTendReading(
          value: 7.2,
          testedAt: DateTime(2026, 6, 29, 8, 45),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
      ],
    ),
    FullTendMonth(
      month: DateTime(2026, 5),
      readings: [
        FullTendReading(
          value: 5.9,
          testedAt: DateTime(2026, 5, 12, 8, 15),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
      ],
    ),
    FullTendMonth(month: DateTime(2026, 4), readings: const []),
  ];
});

final fullTendTestosteroneMonthsProvider = Provider<List<FullTendMonth>>((ref) {
  return [
    FullTendMonth(
      month: DateTime(2026, 7),
      readings: [
        FullTendReading(
          value: 520,
          testedAt: DateTime(2026, 7, 3, 8, 2),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
        FullTendReading(
          value: 560,
          testedAt: DateTime(2026, 7, 5, 11, 31),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
      ],
    ),
    FullTendMonth(
      month: DateTime(2026, 6),
      readings: [
        FullTendReading(
          value: 520,
          testedAt: DateTime(2026, 6, 25, 8, 2),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
        FullTendReading(
          value: 680,
          testedAt: DateTime(2026, 6, 27, 8, 31),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
        FullTendReading(
          value: 610,
          testedAt: DateTime(2026, 6, 29, 9, 15),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
      ],
    ),
    FullTendMonth(
      month: DateTime(2026, 5),
      readings: [
        FullTendReading(
          value: 590,
          testedAt: DateTime(2026, 5, 12, 8, 15),
          periodLabel: 'Morning',
          status: FullTendRangeStatus.normal,
        ),
      ],
    ),
    FullTendMonth(month: DateTime(2026, 4), readings: const []),
  ];
});
