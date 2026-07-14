import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tester_kit/features/home/models/home_test_report.dart';

final homeTestReportsProvider = Provider<List<HomeTestReport>>((ref) {
  return const [
    HomeTestReport(
      type: TestType.cortisol,
      label: 'Cortisol',
      dateLabel: 'MORNING  ·  JUL 5, 7:25 AM',
      completedSteps: 2,
      result: '4–6',
      unit: 'ng/mL',
      rangeStatus: 'Normal range',
      lowRange: 'Low  ·  0–1',
      normalRange: 'Normal  ·  1–7.5',
      highRange: 'High  ·  7.5+',
      markerPosition: 0.48,
      steps: [
        TestStep(eyebrow: 'TEST 1 OF 3', title: 'First morning test', description: 'Take your first test shortly after waking.'),
        TestStep(eyebrow: 'TEST 2 OF 3', title: 'Second morning test', description: 'Space tests 2 days apart for best trend data.'),
        TestStep(eyebrow: 'NEXT:  TEST 3 OF 3', title: 'Test tomorrow morning · aim ~8am', description: 'Space tests 2 days apart for best trend data'),
      ],
    ),
    HomeTestReport(
      type: TestType.testosterone,
      label: 'Testosterone',
      dateLabel: 'MORNING  ·  JUL 5, 7:25 AM',
      completedSteps: 1,
      result: '520',
      unit: 'ng/dL',
      rangeStatus: 'Normal range',
      lowRange: 'Low  ·  <300',
      normalRange: 'Normal  ·  300–900',
      highRange: 'High  ·  900+',
      markerPosition: 0.56,
      steps: [
        TestStep(eyebrow: 'TEST 1 OF 3', title: 'First morning test', description: 'Complete your test before eating or exercising.'),
        TestStep(eyebrow: 'NEXT:  TEST 2 OF 3', title: 'Test in two days · aim ~8am', description: 'Test at a similar time for a more useful comparison.'),
        TestStep(eyebrow: 'NEXT:  TEST 3 OF 3', title: 'Final morning test · aim ~8am', description: 'Your full report unlocks after this final reading.'),
      ],
    ),
  ];
});
