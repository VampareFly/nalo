import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalo/features/home/models/home_test_report.dart';
import 'package:nalo/features/home/presentation/widgets/home_test_report_card.dart';
import 'package:nalo/features/home/providers/home_test_reports_provider.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:nalo/features/notifications/services/notification_permission_service.dart';

void main() {
  testWidgets('a single product does not show product navigation arrows', (tester) async {
    await _pumpCard(
      tester,
      items: const [
        HomeTestProductItem(
          HomeTestProduct(
            type: TestType.testosterone,
            label: 'Testosterone',
            title: 'Try Testosterone',
            description: 'Track your energy.',
            price: r'$18',
          ),
        ),
      ],
    );

    expect(find.text('Try Testosterone'), findsOneWidget);
    expect(find.byKey(const ValueKey('product_previous')), findsNothing);
    expect(find.byKey(const ValueKey('product_next')), findsNothing);
  });

  testWidgets('a completed report shows the report summary action', (tester) async {
    await _pumpCard(tester, items: const [HomeTestReportItem(_completedReport)]);

    expect(find.text('🎉 Kit complete — report ready'), findsOneWidget);
    expect(find.text('View summary of all 3 results'), findsOneWidget);
    expect(find.byKey(const ValueKey('completed_report_summary')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('completed_report_summary'))).height, 88);
    expect(find.text('Remind me'), findsNothing);
  });

  testWidgets('multiple products expose only valid navigation directions', (tester) async {
    await _pumpCard(
      tester,
      items: const [
        HomeTestProductItem(
          HomeTestProduct(
            type: TestType.cortisol,
            label: 'Cortisol',
            title: 'Try Cortisol',
            description: 'Track your stress response.',
            price: r'$18',
          ),
        ),
        HomeTestProductItem(
          HomeTestProduct(
            type: TestType.testosterone,
            label: 'Testosterone',
            title: 'Try Testosterone',
            description: 'Track your energy.',
            price: r'$18',
          ),
        ),
      ],
    );

    expect(find.byKey(const ValueKey('product_previous')), findsNothing);
    expect(find.byKey(const ValueKey('product_next')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('product_next')));
    await tester.pumpAndSettle();

    expect(find.text('Try Testosterone'), findsOneWidget);
    expect(find.byKey(const ValueKey('product_previous')), findsOneWidget);
    expect(find.byKey(const ValueKey('product_next')), findsNothing);
  });
}

Future<void> _pumpCard(WidgetTester tester, {required List<HomeTestCardItem> items}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        homeTestCardItemsProvider.overrideWithValue(items),
        notificationPermissionServiceProvider.overrideWithValue(_NotificationPermissionService()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 393, child: HomeTestReportCard()))),
      ),
    ),
  );
}

class _NotificationPermissionService implements NotificationPermissionService {
  @override
  Future<bool> isNotificationPermissionEnabled() async => false;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> requestNotificationPermission() async => false;
}

const _completedReport = HomeTestReport(
  type: TestType.cortisol,
  label: 'Cortisol',
  dateLabel: 'MORNING',
  completedSteps: 3,
  result: '4–6',
  unit: 'ng/mL',
  rangeStatus: 'Normal range',
  lowRange: 'Low',
  normalRange: 'Normal',
  highRange: 'High',
  markerPosition: 0.5,
  steps: [
    TestStep(eyebrow: 'TEST 1 OF 3', title: 'One', description: 'One'),
    TestStep(eyebrow: 'TEST 2 OF 3', title: 'Two', description: 'Two'),
    TestStep(eyebrow: 'TEST 3 OF 3', title: 'Three', description: 'Three'),
  ],
);
