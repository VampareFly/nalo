import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalo/features/full_tend/models/full_tend_month.dart';
import 'package:nalo/features/full_tend/presentation/pages/full_tend_page.dart';
import 'package:nalo/features/full_tend/providers/full_tend_provider.dart';

void main() {
  FullTendReading reading(int day, int hour) => FullTendReading(
    value: 6 + day / 10,
    testedAt: DateTime(2026, 7, day, hour),
    periodLabel: 'Morning',
    status: FullTendRangeStatus.normal,
  );

  Future<void> pumpMonth(WidgetTester tester, List<FullTendReading> readings) async {
    final month = FullTendMonth(month: DateTime(2026, 7), readings: readings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fullTendMonthsProvider.overrideWithValue([month])],
        child: const MaterialApp(home: FullTendPage()),
      ),
    );
  }

  testWidgets('zero readings shows empty chart and first-test reminder', (tester) async {
    await pumpMonth(tester, const []);

    expect(find.byKey(const Key('empty-chart')), findsOneWidget);
    expect(find.text('NEXT: TEST 1 OF 3'), findsOneWidget);
    expect(find.byKey(const Key('pending-report')), findsOneWidget);
  });

  testWidgets('one reading shows second-test reminder', (tester) async {
    await pumpMonth(tester, [reading(3, 8)]);

    expect(find.text('NEXT: TEST 2 OF 3'), findsOneWidget);
    expect(find.textContaining('Cortisol avg'), findsOneWidget);
  });

  testWidgets('switches between cortisol and testosterone', (tester) async {
    await pumpMonth(tester, [reading(3, 8)]);

    await tester.tap(find.text('Testosterone'));
    await tester.pump();

    expect(find.textContaining('Testosterone avg'), findsOneWidget);
    expect(find.textContaining('ng/dL'), findsWidgets);
  });

  testWidgets('two readings show timing warning when times differ over two hours', (tester) async {
    await pumpMonth(tester, [reading(3, 8), reading(5, 11)]);

    expect(find.text('NEXT: TEST 3 OF 3'), findsOneWidget);
    expect(find.byKey(const Key('timing-warning')), findsOneWidget);
  });

  testWidgets('three readings show complete report and subscription', (tester) async {
    await pumpMonth(tester, [reading(1, 8), reading(3, 9), reading(5, 10)]);
    await tester.scrollUntilVisible(find.text('SUBSCRIBE & SAVE'), 300);

    expect(find.byKey(const Key('completed-report')), findsOneWidget);
    expect(find.text('WHAT THIS SCORE MAY MEAN'), findsOneWidget);
    expect(find.text('SUBSCRIBE & SAVE'), findsOneWidget);
    expect(find.byKey(const Key('pending-report')), findsNothing);
  });
}
