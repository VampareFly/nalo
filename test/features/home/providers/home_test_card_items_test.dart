import 'package:flutter_test/flutter_test.dart';
import 'package:nalo/features/home/models/home_test_report.dart';
import 'package:nalo/features/home/providers/home_test_reports_provider.dart';

void main() {
  const cortisolProduct = HomeTestProduct(
    type: TestType.cortisol,
    label: 'Cortisol',
    title: 'Try Cortisol',
    description: 'Cortisol description',
    price: r'$18',
  );
  const testosteroneProduct = HomeTestProduct(
    type: TestType.testosterone,
    label: 'Testosterone',
    title: 'Try Testosterone',
    description: 'Testosterone description',
    price: r'$18',
  );

  test('shows all products when no report exists', () {
    final items = arrangeHomeTestCardItems(
      reports: const [],
      products: const [cortisolProduct, testosteroneProduct],
    );

    expect(items, hasLength(2));
    expect(items, everyElement(isA<HomeTestProductItem>()));
  });

  test('places an existing report before products without reports', () {
    final items = arrangeHomeTestCardItems(
      reports: const [_cortisolReport],
      products: const [cortisolProduct, testosteroneProduct],
    );

    expect(items, hasLength(2));
    expect(items.first, isA<HomeTestReportItem>());
    expect(items.last, isA<HomeTestProductItem>());
    expect(items.last.label, 'Testosterone');
  });

  test('does not recommend products whose report already exists', () {
    final items = arrangeHomeTestCardItems(
      reports: const [_cortisolReport, _testosteroneReport],
      products: const [cortisolProduct, testosteroneProduct],
    );

    expect(items, hasLength(2));
    expect(items, everyElement(isA<HomeTestReportItem>()));
  });

  group('home test card demo scenarios', () {
    test('noReports returns no reports', () {
      expect(reportsForHomeTestCardDemoScenario(HomeTestCardDemoScenario.noReports), isEmpty);
    });

    test('cortisolOnly returns one in-progress Cortisol report', () {
      final reports = reportsForHomeTestCardDemoScenario(HomeTestCardDemoScenario.cortisolOnly);

      expect(reports, hasLength(1));
      expect(reports.single.type, TestType.cortisol);
      expect(reports.single.completedSteps, 2);
    });

    test('testosteroneOnly returns one in-progress Testosterone report', () {
      final reports = reportsForHomeTestCardDemoScenario(HomeTestCardDemoScenario.testosteroneOnly);

      expect(reports, hasLength(1));
      expect(reports.single.type, TestType.testosterone);
      expect(reports.single.completedSteps, 1);
    });

    test('bothReports returns both in-progress reports', () {
      final reports = reportsForHomeTestCardDemoScenario(HomeTestCardDemoScenario.bothReports);

      expect(reports.map((report) => report.type), [TestType.cortisol, TestType.testosterone]);
    });

    test('cortisolCompleted returns one completed Cortisol report', () {
      final reports = reportsForHomeTestCardDemoScenario(HomeTestCardDemoScenario.cortisolCompleted);

      expect(reports, hasLength(1));
      expect(reports.single.type, TestType.cortisol);
      expect(reports.single.completedSteps, 3);
    });

    test('bothCompleted returns two completed reports', () {
      final reports = reportsForHomeTestCardDemoScenario(HomeTestCardDemoScenario.bothCompleted);

      expect(reports, hasLength(2));
      expect(reports, everyElement(predicate<HomeTestReport>((report) => report.completedSteps == 3)));
    });
  });
}

const _steps = [
  TestStep(eyebrow: 'TEST 1 OF 3', title: 'One', description: 'One'),
  TestStep(eyebrow: 'TEST 2 OF 3', title: 'Two', description: 'Two'),
  TestStep(eyebrow: 'TEST 3 OF 3', title: 'Three', description: 'Three'),
];

const _cortisolReport = HomeTestReport(
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
  steps: _steps,
);

const _testosteroneReport = HomeTestReport(
  type: TestType.testosterone,
  label: 'Testosterone',
  dateLabel: 'MORNING',
  completedSteps: 3,
  result: '520',
  unit: 'ng/dL',
  rangeStatus: 'Normal range',
  lowRange: 'Low',
  normalRange: 'Normal',
  highRange: 'High',
  markerPosition: 0.5,
  steps: _steps,
);
