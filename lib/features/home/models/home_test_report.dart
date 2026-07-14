enum TestType { cortisol, testosterone }

class TestStep {
  const TestStep({required this.eyebrow, required this.title, required this.description});

  final String eyebrow;
  final String title;
  final String description;
}

class HomeTestReport {
  const HomeTestReport({
    required this.type,
    required this.label,
    required this.dateLabel,
    required this.completedSteps,
    required this.result,
    required this.unit,
    required this.rangeStatus,
    required this.lowRange,
    required this.normalRange,
    required this.highRange,
    required this.markerPosition,
    required this.steps,
  });

  final TestType type;
  final String label;
  final String dateLabel;
  final int completedSteps;
  final String result;
  final String unit;
  final String rangeStatus;
  final String lowRange;
  final String normalRange;
  final String highRange;
  final double markerPosition;
  final List<TestStep> steps;

  int get totalSteps => steps.length;
  List<TestStep> get pendingSteps => steps.skip(completedSteps).toList(growable: false);
}
