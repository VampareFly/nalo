// 检测状态层：驱动页面流程与计时，并上报图片分析、结果确认和结果读取请求。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';
import 'package:nalo/features/test_flow/providers/recent_tests_cache_provider.dart';
import 'package:nalo/features/test_flow/repositories/test_flow_repository.dart';

const _unset = Object();

/// 记录检测流程页面是否位于顶层，供外部跳转避免重复打开流程。
final testFlowVisibilityProvider = Provider<TestFlowVisibilityTracker>(
  (ref) => TestFlowVisibilityTracker(),
);

/// 由检测流程的 RouteAware 回调维护顶层标记，不触发 Widget 重建。
class TestFlowVisibilityTracker {
  bool _isVisible = false;

  /// 当前检测流程页面是否位于顶层。
  bool get isVisible => _isVisible;

  /// 在页面进入或离开顶层时同步展示标记。
  void setVisible(bool isVisible) => _isVisible = isVisible;
}

/// 检测流程的不可变页面状态。
class TestFlowState {
  const TestFlowState({
    this.source,
    this.step = TestFlowStep.about,
    this.type = DetectionType.cortisol,
    this.config = DetectionConfig.fallback,
    this.confirmationConfig,
    this.recent = const [],
    this.timerStatus = TimerStatus.idle,
    this.remaining = Duration.zero,
    this.timerDuration = Duration.zero,
    this.photoPath,
    this.analysis,
    this.selectedLevel,
    this.sampledAt,
    this.selectedTimePeriod,
    this.typicalRangeOverride,
    this.confirmRecordId,
    this.result,
    this.analysisError,
    this.isLoading = false,
    this.errorMessage,
  });

  final AnalyticsTestFlowSource? source;
  final TestFlowStep step;
  final DetectionType type;
  final DetectionConfig config;
  final DetectionConfig? confirmationConfig;
  final List<RecentDetection> recent;
  final TimerStatus timerStatus;
  final Duration remaining;
  final Duration timerDuration;
  final String? photoPath;
  final DetectionAnalysis? analysis;
  final String? selectedLevel;
  final DateTime? sampledAt;
  final String? selectedTimePeriod;
  final String? typicalRangeOverride;
  final int? confirmRecordId;
  final DetectionResult? result;
  final DetectionAnalysisError? analysisError;
  final bool isLoading;
  final String? errorMessage;

  /// 结果确认页使用进入页面时冻结的配置，其他页面使用最新全局配置。
  DetectionConfig get effectiveConfig => confirmationConfig ?? config;

  /// 当前激素类型对应的可选结果区间。
  DetectionOptionGroup get readingOptions => effectiveConfig.readingsFor(type);

  TestFlowState copyWith({
    TestFlowStep? step,
    DetectionType? type,
    DetectionConfig? config,
    Object? confirmationConfig = _unset,
    List<RecentDetection>? recent,
    TimerStatus? timerStatus,
    Duration? remaining,
    Duration? timerDuration,
    Object? photoPath = _unset,
    Object? analysis = _unset,
    Object? selectedLevel = _unset,
    Object? sampledAt = _unset,
    Object? selectedTimePeriod = _unset,
    Object? typicalRangeOverride = _unset,
    Object? confirmRecordId = _unset,
    Object? result = _unset,
    Object? analysisError = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) => TestFlowState(
    source: source,
    step: step ?? this.step,
    type: type ?? this.type,
    config: config ?? this.config,
    confirmationConfig: identical(confirmationConfig, _unset)
        ? this.confirmationConfig
        : confirmationConfig as DetectionConfig?,
    recent: recent ?? this.recent,
    timerStatus: timerStatus ?? this.timerStatus,
    remaining: remaining ?? this.remaining,
    timerDuration: timerDuration ?? this.timerDuration,
    photoPath: identical(photoPath, _unset)
        ? this.photoPath
        : photoPath as String?,
    analysis: identical(analysis, _unset)
        ? this.analysis
        : analysis as DetectionAnalysis?,
    selectedLevel: identical(selectedLevel, _unset)
        ? this.selectedLevel
        : selectedLevel as String?,
    sampledAt: identical(sampledAt, _unset)
        ? this.sampledAt
        : sampledAt as DateTime?,
    selectedTimePeriod: identical(selectedTimePeriod, _unset)
        ? this.selectedTimePeriod
        : selectedTimePeriod as String?,
    typicalRangeOverride: identical(typicalRangeOverride, _unset)
        ? this.typicalRangeOverride
        : typicalRangeOverride as String?,
    confirmRecordId: identical(confirmRecordId, _unset)
        ? this.confirmRecordId
        : confirmRecordId as int?,
    result: identical(result, _unset)
        ? this.result
        : result as DetectionResult?,
    analysisError: identical(analysisError, _unset)
        ? this.analysisError
        : analysisError as DetectionAnalysisError?,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
  );
}

/// 管理一次检测会话的页面流转、计时器与接口提交。
class TestFlowController extends Notifier<TestFlowState> {
  Timer? _ticker;
  DateTime? _endsAt;
  bool _configInitialized = false;
  Future<void>? _configInitialization;
  int _recentRequestGeneration = 0;

  @override
  TestFlowState build() {
    ref.onDispose(_stopTicker);
    return const TestFlowState();
  }

  /// 入口触发时记录本次检测会话来源，后续检测业务事件统一沿用。
  void beginSession(AnalyticsTestFlowSource source) {
    state = TestFlowState(
      source: source,
      type: state.type,
      config: state.config,
      recent: state.recent,
    );
  }

  /// 检测路由退出后清空会话来源，避免污染流程外的同名事件。
  void endSession() {
    _stopTicker();
    state = TestFlowState(config: state.config, recent: state.recent);
  }

  /// 每次进入检测页时确保配置可用，并在共享缓存缺失时加载最近三次结果。
  Future<void> initialize() async {
    await initializeConfig();
    await _ensureRecent(state.type);
  }

  /// App 冷启动或首次进入模块时发布本地配置，并在后台刷新远端配置。
  Future<void> initializeConfig() {
    if (_configInitialized) return Future.value();
    final inProgress = _configInitialization;
    if (inProgress != null) return inProgress;
    late final Future<void> operation;
    operation = _performInitializeConfig().whenComplete(() {
      if (identical(_configInitialization, operation)) {
        _configInitialization = null;
      }
    });
    _configInitialization = operation;
    return operation;
  }

  /// Repository 可用后发布本地配置，并只在本次进程首次成功启动一次远端刷新。
  Future<void> _performInitializeConfig() async {
    final repository = await ref.read(testFlowRepositoryProvider.future);
    state = state.copyWith(config: repository.readConfig());
    _configInitialized = true;
    unawaited(_refreshConfig(repository));
  }

  Future<void> _refreshConfig(TestFlowRepository repository) async {
    try {
      final config = await repository.refreshConfig();
      state = state.copyWith(config: config);
    } catch (_) {
      // Cached or bundled configuration remains active.
    }
  }

  Future<void> _ensureRecent(DetectionType type) async {
    final cache = ref.read(recentTestsCacheProvider);
    if (cache.hasLoaded(type)) {
      state = state.copyWith(
        recent: cache.itemsFor(type),
        isLoading: false,
        errorMessage: null,
      );
      return;
    }
    final generation = ++_recentRequestGeneration;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final items = await ref
          .read(recentTestsCacheProvider.notifier)
          .loadIfNeeded(type, () async {
            final repository = await ref.read(
              testFlowRepositoryProvider.future,
            );
            return (await repository.recent(type)).recent;
          });
      if (generation != _recentRequestGeneration || state.type != type) return;
      state = state.copyWith(recent: items, isLoading: false);
    } catch (_) {
      if (generation != _recentRequestGeneration || state.type != type) return;
      state = state.copyWith(isLoading: false, errorMessage: null);
    }
  }

  /// 切换检测类型后优先读取共享缓存，未加载时才请求最近三次记录。
  Future<void> selectType(DetectionType type) async {
    if (state.type == type) return;
    _recentRequestGeneration++;
    state = state.copyWith(type: type, recent: const []);
    await _ensureRecent(type);
  }

  void showBeforeStart() =>
      state = state.copyWith(step: TestFlowStep.beforeStart);

  /// 进入口腔采样倒计时。
  void beginSwab() =>
      _enterTimer(TestFlowStep.swab, const Duration(seconds: 15));

  /// 进入试纸浸泡倒计时。
  void beginDip() => _enterTimer(TestFlowStep.dip, const Duration(seconds: 30));

  /// 进入必须等待满十五分钟的显色倒计时。
  void beginDevelop() =>
      _enterTimer(TestFlowStep.develop, const Duration(minutes: 15));

  void _enterTimer(TestFlowStep step, Duration duration) {
    _stopTicker();
    state = state.copyWith(
      step: step,
      timerStatus: TimerStatus.running,
      remaining: duration,
      timerDuration: duration,
    );
    _endsAt = DateTime.now().add(duration);
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => syncTimer(),
    );
  }

  /// 按结束时间计算剩余时长，确保切后台或锁屏期间仍自然流逝。
  void syncTimer() {
    if (state.timerStatus != TimerStatus.running || _endsAt == null) return;
    final remaining = _endsAt!.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _stopTicker();
      final completedStep = state.step;
      final completedDuration = state.timerDuration;
      state = state.copyWith(
        timerStatus: TimerStatus.complete,
        remaining: Duration.zero,
      );
      unawaited(
        ref
            .read(analyticsProvider)
            .report(
              AnalyticsEvent.testTimerComplete,
              properties: {
                if (state.source != null)
                  AnalyticsEventProperty.source: state.source!.value,
                AnalyticsEventProperty.pageName: _pageNameForStep(
                  completedStep,
                ).value,
                AnalyticsEventProperty.detectionType: _analyticsDetectionType(
                  state.type,
                ).value,
                AnalyticsEventProperty.timerDurationSeconds:
                    completedDuration.inSeconds,
              },
            ),
      );
      return;
    }
    state = state.copyWith(remaining: remaining);
  }

  /// 暂停页面计时；试纸本身的显色过程不会随之暂停。
  void pauseTimer() {
    syncTimer();
    if (state.timerStatus != TimerStatus.running) return;
    _stopTicker();
    state = state.copyWith(timerStatus: TimerStatus.paused);
  }

  /// 从暂停时保存的剩余时长继续计时。
  void resumeTimer() {
    if (state.timerStatus != TimerStatus.paused) return;
    _endsAt = DateTime.now().add(state.remaining);
    state = state.copyWith(timerStatus: TimerStatus.running);
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => syncTimer(),
    );
  }

  /// 经用户确认后跳过当前计时，并直接进入下一个检测节点。
  void skipTimer() {
    _stopTicker();
    state = state.copyWith(
      timerStatus: TimerStatus.complete,
      remaining: Duration.zero,
    );
    nextAfterTimer();
  }

  /// 按当前计时步骤进入下一检测节点。
  void nextAfterTimer() {
    switch (state.step) {
      case TestFlowStep.swab:
        beginDip();
        return;
      case TestFlowStep.dip:
        beginDevelop();
        return;
      case TestFlowStep.develop:
        state = state.copyWith(step: TestFlowStep.capture);
        return;
      default:
        return;
    }
  }

  /// 停止当前计时并返回流程上一步；已完成的前一步保持完成状态。
  void previousTimerStep() {
    _stopTicker();
    _endsAt = null;
    switch (state.step) {
      case TestFlowStep.swab:
        state = state.copyWith(
          step: TestFlowStep.beforeStart,
          timerStatus: TimerStatus.idle,
          remaining: Duration.zero,
          timerDuration: Duration.zero,
        );
        return;
      case TestFlowStep.dip:
        state = state.copyWith(
          step: TestFlowStep.swab,
          timerStatus: TimerStatus.complete,
          remaining: Duration.zero,
          timerDuration: const Duration(seconds: 15),
        );
        return;
      case TestFlowStep.develop:
        state = state.copyWith(
          step: TestFlowStep.dip,
          timerStatus: TimerStatus.complete,
          remaining: Duration.zero,
          timerDuration: const Duration(seconds: 30),
        );
        return;
      default:
        return;
    }
  }

  void showCapture() => state = state.copyWith(step: TestFlowStep.capture);

  void setPhoto(String path) => state = state.copyWith(
    step: TestFlowStep.preview,
    photoPath: path,
    analysisError: null,
    errorMessage: null,
  );

  void retake() => state = state.copyWith(
    step: TestFlowStep.capture,
    photoPath: null,
    analysisError: null,
    errorMessage: null,
  );

  /// 上传已拍照片，并在识别成功后进入可人工修正的结果确认页。
  Future<void> analyzePhoto() async {
    final path = state.photoPath;
    if (path == null || state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      analysisError: null,
      errorMessage: null,
    );
    var requestSucceeded = false;
    try {
      final repository = await ref.read(testFlowRepositoryProvider.future);
      final analysis = await repository.analyze(
        type: state.type,
        imagePath: path,
      );
      requestSucceeded = true;
      unawaited(
        ref
            .read(analyticsProvider)
            .report(
              AnalyticsEvent.testPhotoAnalysisRequestResult,
              properties: {
                if (state.source != null)
                  AnalyticsEventProperty.source: state.source!.value,
                AnalyticsEventProperty.pageName:
                    AnalyticsPageName.testPhotoPreview.value,
                AnalyticsEventProperty.detectionType: _analyticsDetectionType(
                  state.type,
                ).value,
                AnalyticsEventProperty.testId: analysis.id.toString(),
                AnalyticsEventProperty.isSuccess: 1,
                AnalyticsEventProperty.failReason: '',
              },
            ),
      );
      final readingOptions = state.config.readingsFor(state.type).options;
      final selectedLevel =
          readingOptions.any(
            (option) => option.value == analysis.aiValueResultLevel,
          )
          ? analysis.aiValueResultLevel
          : null;
      final selectedTimePeriod =
          state.config.timePeriods.options.any(
            (option) => option.value == analysis.detectionTimePeriod,
          )
          ? analysis.detectionTimePeriod
          : null;
      state = state.copyWith(
        step: TestFlowStep.confirm,
        analysis: analysis,
        confirmationConfig: state.config,
        selectedLevel: selectedLevel,
        sampledAt: DateTime.now(),
        selectedTimePeriod: selectedTimePeriod,
        typicalRangeOverride: null,
        isLoading: false,
      );
    } catch (error) {
      if (!requestSucceeded) {
        unawaited(
          ref
              .read(analyticsProvider)
              .report(
                AnalyticsEvent.testPhotoAnalysisRequestResult,
                properties: {
                  if (state.source != null)
                    AnalyticsEventProperty.source: state.source!.value,
                  AnalyticsEventProperty.pageName:
                      AnalyticsPageName.testPhotoPreview.value,
                  AnalyticsEventProperty.detectionType: _analyticsDetectionType(
                    state.type,
                  ).value,
                  AnalyticsEventProperty.testId: '',
                  AnalyticsEventProperty.isSuccess: 0,
                  AnalyticsEventProperty.failReason: _analyticsFailReason(
                    error,
                  ),
                },
              ),
        );
      }
      final analysisError = switch (error) {
        ApiException(code: 6000000) => DetectionAnalysisError.recognitionFailed,
        ApiException(code: 6000001) =>
          DetectionAnalysisError.invalidControlLine,
        _ => null,
      };
      final message = switch (analysisError) {
        DetectionAnalysisError.recognitionFailed =>
          'We could not recognize the test cassette. Please retake the photo.',
        DetectionAnalysisError.invalidControlLine =>
          'The control line was not detected. Please retake the photo.',
        null => _friendlyError(error),
      };
      state = state.copyWith(
        isLoading: false,
        analysisError: analysisError,
        errorMessage: message,
      );
    }
  }

  void selectLevel(String value) =>
      state = state.copyWith(selectedLevel: value);
  void selectSampleDate(DateTime value) =>
      state = state.copyWith(sampledAt: value);

  /// 更新用户选择的检测时段，并同步该时段与检测类型对应的典型范围。
  void selectTimePeriod(String value) {
    final matches = state.effectiveConfig.timePeriods.options.where(
      (option) => option.value == value,
    );
    final typicalRange = matches.isEmpty
        ? null
        : matches.first.typicalRangeFor(state.type);
    state = state.copyWith(
      selectedTimePeriod: value,
      typicalRangeOverride: typicalRange,
    );
  }

  /// 提交人工确认结果，再读取结果页数据并按 show_popup 决定是否展示庆祝页。
  Future<void> saveResult() async {
    final analysis = state.analysis;
    final level = state.selectedLevel;
    final period = state.selectedTimePeriod;
    if (analysis == null ||
        level == null ||
        period == null ||
        state.isLoading) {
      return;
    }
    final sampledAt = state.sampledAt;
    final requestProperties = <AnalyticsEventProperty, Object>{
      if (state.source != null)
        AnalyticsEventProperty.source: state.source!.value,
      AnalyticsEventProperty.pageName:
          AnalyticsPageName.testResultConfirm.value,
      AnalyticsEventProperty.detectionType: _analyticsDetectionType(
        state.type,
      ).value,
      AnalyticsEventProperty.testId: analysis.id.toString(),
      AnalyticsEventProperty.finalLevel: level,
      AnalyticsEventProperty.sampledAt: sampledAt == null
          ? ''
          : _analyticsDate(sampledAt),
      AnalyticsEventProperty.timePeriod: period,
    };
    state = state.copyWith(isLoading: true, errorMessage: null);
    var confirmRequestSucceeded = false;
    try {
      final repository = await ref.read(testFlowRepositoryProvider.future);
      final confirmation = await repository.confirm(
        type: state.type,
        finalLevel: level,
        sampledAt: sampledAt,
        timePeriod: period,
        detectionId: analysis.id,
      );
      confirmRequestSucceeded = true;
      unawaited(
        ref
            .read(analyticsProvider)
            .report(
              AnalyticsEvent.testResultConfirmRequestResult,
              properties: {
                ...requestProperties,
                AnalyticsEventProperty.showPopup: confirmation.showPopup
                    ? 1
                    : 0,
                AnalyticsEventProperty.isSuccess: 1,
                AnalyticsEventProperty.failReason: '',
              },
            ),
      );
      DetectionResult? result;
      String? resultError;
      try {
        result = await repository.fullResult(state.type);
        unawaited(
          ref
              .read(analyticsProvider)
              .report(
                AnalyticsEvent.testResultRequestResult,
                properties: {
                  if (state.source != null)
                    AnalyticsEventProperty.source: state.source!.value,
                  AnalyticsEventProperty.pageName:
                      AnalyticsPageName.testResultConfirm.value,
                  AnalyticsEventProperty.detectionType: _analyticsDetectionType(
                    state.type,
                  ).value,
                  AnalyticsEventProperty.testId: analysis.id.toString(),
                  AnalyticsEventProperty.isSuccess: 1,
                  AnalyticsEventProperty.failReason: '',
                },
              ),
        );
        ref
            .read(recentTestsCacheProvider.notifier)
            .replace(state.type, result.recent);
      } catch (error) {
        unawaited(
          ref
              .read(analyticsProvider)
              .report(
                AnalyticsEvent.testResultRequestResult,
                properties: {
                  if (state.source != null)
                    AnalyticsEventProperty.source: state.source!.value,
                  AnalyticsEventProperty.pageName:
                      AnalyticsPageName.testResultConfirm.value,
                  AnalyticsEventProperty.detectionType: _analyticsDetectionType(
                    state.type,
                  ).value,
                  AnalyticsEventProperty.testId: analysis.id.toString(),
                  AnalyticsEventProperty.isSuccess: 0,
                  AnalyticsEventProperty.failReason: _analyticsFailReason(
                    error,
                  ),
                },
              ),
        );
        resultError = _friendlyError(error);
      }
      state = state.copyWith(
        step: confirmation.showPopup
            ? TestFlowStep.milestone
            : TestFlowStep.result,
        confirmRecordId: confirmation.confirmRecordId,
        result: result,
        recent: result?.recent ?? state.recent,
        isLoading: false,
        errorMessage: resultError,
      );
    } catch (error) {
      if (!confirmRequestSucceeded) {
        unawaited(
          ref
              .read(analyticsProvider)
              .report(
                AnalyticsEvent.testResultConfirmRequestResult,
                properties: {
                  ...requestProperties,
                  AnalyticsEventProperty.showPopup: -1,
                  AnalyticsEventProperty.isSuccess: 0,
                  AnalyticsEventProperty.failReason: _analyticsFailReason(
                    error,
                  ),
                },
              ),
        );
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  void showResult() => state = state.copyWith(step: TestFlowStep.result);

  /// 清理计时与本次检测数据，同时保留已加载的全局配置和当前最近结果。
  void reset() {
    _stopTicker();
    const initialType = DetectionType.cortisol;
    final cache = ref.read(recentTestsCacheProvider);
    state = TestFlowState(
      source: state.source,
      type: initialType,
      config: state.config,
      recent: cache.hasLoaded(initialType)
          ? cache.itemsFor(initialType)
          : const [],
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
  }

  String _friendlyError(Object error) {
    return switch (error) {
      ApiException(:final message) when message.trim().isNotEmpty => message,
      NetworkException(type: NetworkExceptionType.timeout) =>
        'The request timed out. Please try again.',
      NetworkException(type: NetworkExceptionType.connection) =>
        'Check your internet connection and try again.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}

AnalyticsDetectionType _analyticsDetectionType(DetectionType type) {
  return switch (type) {
    DetectionType.cortisol => AnalyticsDetectionType.cortisol,
    DetectionType.testosterone => AnalyticsDetectionType.testosterone,
  };
}

AnalyticsPageName _pageNameForStep(TestFlowStep step) {
  return switch (step) {
    TestFlowStep.swab => AnalyticsPageName.testSwab,
    TestFlowStep.dip => AnalyticsPageName.testDip,
    TestFlowStep.develop => AnalyticsPageName.testDevelop,
    _ => throw StateError('The current step is not a timer page.'),
  };
}

String _analyticsFailReason(Object error) {
  return switch (error) {
    ApiException(:final code, :final message) => '$code: $message',
    NetworkException(type: NetworkExceptionType.timeout) =>
      'network_timeout: Request timed out',
    NetworkException(type: NetworkExceptionType.connection) =>
      'network_error: Request failed',
    ResponseFormatException() => 'invalid_response: Response is invalid',
    _ => 'unknown_error: Unknown request error',
  };
}

String _analyticsDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// 检测流程页面统一监听和调用的 Riverpod Provider。
final testFlowProvider = NotifierProvider<TestFlowController, TestFlowState>(
  TestFlowController.new,
);
