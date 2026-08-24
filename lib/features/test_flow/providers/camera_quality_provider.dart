// 相机质量状态层：节流实时帧分析，并通过连续合格帧稳定拍照按钮状态。

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/test_flow/models/camera_quality_models.dart';
import 'package:nalo/features/test_flow/services/camera_quality_analyzer.dart';

/// 管理拍照页实时质量检测与 Ready 状态防抖。
class CameraQualityController extends Notifier<CameraQualityState> {
  static const _analysisInterval = Duration(milliseconds: 250);
  static const _requiredGoodFrames = 3;

  final CameraQualityAnalyzer _analyzer = const CameraQualityAnalyzer();
  DateTime? _lastAnalyzedAt;
  List<int>? _previousSamples;
  int _goodFrames = 0;

  @override
  CameraQualityState build() => const CameraQualityState();

  /// 开始新的相机会话时清理上一轮质量数据。
  void reset() {
    _lastAnalyzedAt = null;
    _previousSamples = null;
    _goodFrames = 0;
    state = const CameraQualityState();
  }

  /// 以固定频率分析预览帧，避免每帧计算导致相机卡顿。
  void analyze(CameraImage image) {
    final now = DateTime.now();
    final lastAnalyzedAt = _lastAnalyzedAt;
    if (lastAnalyzedAt != null &&
        now.difference(lastAnalyzedAt) < _analysisInterval) {
      return;
    }
    _lastAnalyzedAt = now;
    CameraFrameMetrics metrics;
    try {
      metrics = _analyzer.analyze(image, previousSamples: _previousSamples);
    } catch (_) {
      _goodFrames = 0;
      state = const CameraQualityState();
      return;
    }
    _previousSamples = metrics.luminanceSamples;

    if (metrics.isLightingInvalid) {
      _goodFrames = 0;
      state = const CameraQualityState(
        status: CameraQualityStatus.adjustLighting,
      );
      return;
    }
    if (metrics.isBlurry || metrics.isMoving) {
      _goodFrames = 0;
      state = const CameraQualityState(status: CameraQualityStatus.holdStill);
      return;
    }
    _goodFrames++;
    final ready = _goodFrames >= _requiredGoodFrames;
    state = CameraQualityState(
      status: ready ? CameraQualityStatus.ready : CameraQualityStatus.holdStill,
      canCapture: ready,
    );
  }
}

/// 提供拍照页面共享的实时质量状态。
final cameraQualityProvider =
    NotifierProvider<CameraQualityController, CameraQualityState>(
      CameraQualityController.new,
    );
