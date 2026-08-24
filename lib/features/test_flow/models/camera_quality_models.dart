// 相机质量模型：描述实时预览的简化质量状态和底层图像指标。

/// 拍照页允许展示的三种动态质量状态。
enum CameraQualityStatus { adjustLighting, holdStill, ready }

/// 单帧降采样图像计算得到的质量指标。
class CameraFrameMetrics {
  const CameraFrameMetrics({
    required this.isLightingInvalid,
    required this.isBlurry,
    required this.isMoving,
    required this.luminanceSamples,
  });

  final bool isLightingInvalid;
  final bool isBlurry;
  final bool isMoving;
  final List<int> luminanceSamples;
}

/// 拍照页面消费的稳定质量状态。
class CameraQualityState {
  const CameraQualityState({
    this.status = CameraQualityStatus.holdStill,
    this.canCapture = false,
  });

  final CameraQualityStatus status;
  final bool canCapture;

  /// 当前状态对应的唯一动态提示。
  String get guidance => switch (status) {
    CameraQualityStatus.adjustLighting => 'Adjust the lighting',
    CameraQualityStatus.holdStill => 'Hold still',
    CameraQualityStatus.ready => 'Ready to capture',
  };
}
