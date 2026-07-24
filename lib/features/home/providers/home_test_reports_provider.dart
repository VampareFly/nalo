import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/home/models/home_test_report.dart';

enum HomeTestCardDemoScenario {
  // 两种都没有报告，展示两个商品
  noReports,
  // 只有 Cortisol 报告，Testosterone 展示商品
  cortisolOnly,
  // 只有 Testosterone 报告，Cortisol 展示商品
  testosteroneOnly,
  // 两种都有未完成报告
  bothReports,
  // Cortisol 三步完成，Testosterone 展示商品
  cortisolCompleted,
  // 两种报告都完成
  bothCompleted,
}

// Change this value and Hot Restart to preview another server-data scenario.
const homeTestCardDemoScenario = HomeTestCardDemoScenario.bothReports;

final homeTestReportsProvider = Provider<List<HomeTestReport>>((ref) {
  // TODO: <pf> Replace demo scenarios with reports returned by the repository.
  return reportsForHomeTestCardDemoScenario(homeTestCardDemoScenario);
});

final homeTestProductsProvider = Provider<List<HomeTestProduct>>((ref) {
  return const [
    HomeTestProduct(
      type: TestType.cortisol,
      label: 'Cortisol',
      title: 'Try Cortisol',
      description: 'Track your stress response, sleep, and daily rhythm to build a clearer health baseline.',
      price: r'$18',
    ),
    HomeTestProduct(
      type: TestType.testosterone,
      label: 'Testosterone',
      title: 'Try Testosterone',
      description: 'Track your energy, drive, and muscle health alongside cortisol for a fuller picture.',
      price: r'$18',
    ),
  ];
});

final homeTestCardItemsProvider = Provider<List<HomeTestCardItem>>((ref) {
  return arrangeHomeTestCardItems(reports: ref.watch(homeTestReportsProvider), products: ref.watch(homeTestProductsProvider));
});

List<HomeTestCardItem> arrangeHomeTestCardItems({required List<HomeTestReport> reports, required List<HomeTestProduct> products}) {
  final reportTypes = reports.map((report) => report.type).toSet();

  return [
    ...reports.map(HomeTestReportItem.new),
    ...products.where((product) => !reportTypes.contains(product.type)).map(HomeTestProductItem.new),
  ];
}

List<HomeTestReport> reportsForHomeTestCardDemoScenario(HomeTestCardDemoScenario scenario) {
  return switch (scenario) {
    HomeTestCardDemoScenario.noReports => const [],
    HomeTestCardDemoScenario.cortisolOnly => [_cortisolReport(completedSteps: 2)],
    HomeTestCardDemoScenario.testosteroneOnly => [_testosteroneReport(completedSteps: 1)],
    HomeTestCardDemoScenario.bothReports => [_cortisolReport(completedSteps: 2), _testosteroneReport(completedSteps: 1)],
    HomeTestCardDemoScenario.cortisolCompleted => [_cortisolReport(completedSteps: 3)],
    HomeTestCardDemoScenario.bothCompleted => [_cortisolReport(completedSteps: 3), _testosteroneReport(completedSteps: 3)],
  };
}

HomeTestReport _cortisolReport({required int completedSteps}) {
  return HomeTestReport(
    type: TestType.cortisol,
    label: 'Cortisol',
    dateLabel: 'MORNING  ·  JUL 5, 7:25 AM',
    completedSteps: completedSteps,
    result: '4–6',
    unit: 'ng/mL',
    rangeStatus: 'Normal range',
    lowRange: 'Low  ·  0–1',
    normalRange: 'Normal  ·  1–7.5',
    highRange: 'High  ·  7.5+',
    markerPosition: 0.48,
    steps: const [
      TestStep(eyebrow: 'TEST 1 OF 3', title: 'First morning test', description: 'Take your first test shortly after waking.'),
      TestStep(eyebrow: 'TEST 2 OF 3', title: 'Second morning test', description: 'Space tests 2 days apart for best trend data.'),
      TestStep(
        eyebrow: 'NEXT:  TEST 3 OF 3',
        title: 'Test tomorrow morning · aim ~8am',
        description: 'Space tests 2 days apart for best trend data',
      ),
    ],
  );
}

HomeTestReport _testosteroneReport({required int completedSteps}) {
  return HomeTestReport(
    type: TestType.testosterone,
    label: 'Testosterone',
    dateLabel: 'MORNING  ·  JUL 5, 7:25 AM',
    completedSteps: completedSteps,
    result: '520',
    unit: 'ng/dL',
    rangeStatus: 'Normal range',
    lowRange: 'Low  ·  <300',
    normalRange: 'Normal  ·  300–900',
    highRange: 'High  ·  900+',
    markerPosition: 0.56,
    steps: const [
      TestStep(eyebrow: 'TEST 1 OF 3', title: 'First morning test', description: 'Complete your test before eating or exercising.'),
      TestStep(
        eyebrow: 'NEXT:  TEST 2 OF 3',
        title: 'Test in two days · aim ~8am',
        description: 'Test at a similar time for a more useful comparison.',
      ),
      TestStep(
        eyebrow: 'NEXT:  TEST 3 OF 3',
        title: 'Final morning test · aim ~8am',
        description: 'Your full report unlocks after this final reading.',
      ),
    ],
  );
}
