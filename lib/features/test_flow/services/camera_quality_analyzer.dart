// 相机质量分析器：从双端相机帧中抽取低分辨率亮度数据并计算基础质量指标。

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:nalo/features/test_flow/models/camera_quality_models.dart';

/// 使用轻量纯规则计算光线、模糊和连续帧移动状态。
class CameraQualityAnalyzer {
  const CameraQualityAnalyzer();

  static const _sampleWidth = 96;
  static const _sampleHeight = 96;

  // TODO: <pf> 使用多款 iOS、Android 真机样本校准亮度、模糊和移动阈值。
  static const _minimumMeanLuminance = 45.0;
  static const _maximumMeanLuminance = 220.0;
  static const _maximumDarkRatio = 0.65;
  static const _maximumBrightRatio = 0.65;
  static const _minimumSharpness = 80.0;
  static const _maximumFrameDifference = 14.0;

  /// 分析一帧画面；previousSamples 用于判断手机或画面是否明显移动。
  CameraFrameMetrics analyze(
    CameraImage image, {
    required List<int>? previousSamples,
  }) {
    final samples = _sampleLuminance(image);
    var sum = 0;
    var dark = 0;
    var bright = 0;
    for (final value in samples) {
      sum += value;
      if (value < 35) dark++;
      if (value > 245) bright++;
    }
    final mean = sum / samples.length;
    final darkRatio = dark / samples.length;
    final brightRatio = bright / samples.length;
    final lightingInvalid =
        mean < _minimumMeanLuminance ||
        mean > _maximumMeanLuminance ||
        darkRatio > _maximumDarkRatio ||
        brightRatio > _maximumBrightRatio;

    final sharpness = _sharpness(samples);
    final frameDifference = previousSamples == null
        ? 0.0
        : _frameDifference(samples, previousSamples);
    return CameraFrameMetrics(
      isLightingInvalid: lightingInvalid,
      isBlurry: sharpness < _minimumSharpness,
      isMoving: frameDifference > _maximumFrameDifference,
      luminanceSamples: samples,
    );
  }

  List<int> _sampleLuminance(CameraImage image) {
    final plane = image.planes.first;
    final values = List<int>.filled(_sampleWidth * _sampleHeight, 0);
    final pixelStride = plane.bytesPerPixel ?? 1;
    final isBgra = pixelStride >= 4;
    // 聚焦试纸检测窗附近，避免清晰背景让模糊的 C/T 线错误通过。
    final isLandscapeFrame = image.width > image.height;
    final regionWidth = image.width * (isLandscapeFrame ? 0.30 : 0.18);
    final regionHeight = image.height * (isLandscapeFrame ? 0.18 : 0.30);
    final left = (image.width - regionWidth) / 2;
    final top = (image.height - regionHeight) / 2;

    for (var sampleY = 0; sampleY < _sampleHeight; sampleY++) {
      final y = math.min(
        image.height - 1,
        (top + regionHeight * sampleY / (_sampleHeight - 1)).round(),
      );
      for (var sampleX = 0; sampleX < _sampleWidth; sampleX++) {
        final x = math.min(
          image.width - 1,
          (left + regionWidth * sampleX / (_sampleWidth - 1)).round(),
        );
        final offset = y * plane.bytesPerRow + x * pixelStride;
        values[sampleY * _sampleWidth + sampleX] = isBgra
            ? _bgraLuminance(plane.bytes, offset)
            : plane.bytes[offset];
      }
    }
    return values;
  }

  int _bgraLuminance(Uint8List bytes, int offset) {
    if (offset + 2 >= bytes.length) return 0;
    final blue = bytes[offset];
    final green = bytes[offset + 1];
    final red = bytes[offset + 2];
    return (0.114 * blue + 0.587 * green + 0.299 * red).round();
  }

  double _sharpness(List<int> samples) {
    final values = <double>[];
    var total = 0.0;
    for (var y = 1; y < _sampleHeight - 1; y++) {
      for (var x = 1; x < _sampleWidth - 1; x++) {
        final index = y * _sampleWidth + x;
        final laplacian =
            samples[index - 1] +
            samples[index + 1] +
            samples[index - _sampleWidth] +
            samples[index + _sampleWidth] -
            4 * samples[index];
        final value = laplacian.toDouble();
        values.add(value);
        total += value;
      }
    }
    if (values.isEmpty) return 0;
    final mean = total / values.length;
    var squaredDifference = 0.0;
    for (final value in values) {
      final difference = value - mean;
      squaredDifference += difference * difference;
    }
    return squaredDifference / values.length;
  }

  double _frameDifference(List<int> current, List<int> previous) {
    if (current.length != previous.length) return double.infinity;
    var total = 0;
    for (var index = 0; index < current.length; index++) {
      total += (current[index] - previous[index]).abs();
    }
    return total / current.length;
  }
}
