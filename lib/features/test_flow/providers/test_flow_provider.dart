import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TestType { cortisol, testosterone }

class TestFlowState {
  const TestFlowState({
    this.testType = TestType.cortisol,
    this.capturedAt,
    this.detectedValue = 7.2,
  });

  final TestType testType;
  final DateTime? capturedAt;
  final double detectedValue;

  TestFlowState copyWith({TestType? testType, DateTime? capturedAt, double? detectedValue}) {
    return TestFlowState(
      testType: testType ?? this.testType,
      capturedAt: capturedAt ?? this.capturedAt,
      detectedValue: detectedValue ?? this.detectedValue,
    );
  }
}

class TestFlowController extends Notifier<TestFlowState> {
  @override
  TestFlowState build() => const TestFlowState();

  void selectTestType(TestType type) {
    state = state.copyWith(testType: type);
  }

  void recordCapture(DateTime capturedAt) {
    state = state.copyWith(capturedAt: capturedAt);
  }

  void reset() {
    state = const TestFlowState();
  }
}

final testFlowProvider = NotifierProvider<TestFlowController, TestFlowState>(TestFlowController.new);
