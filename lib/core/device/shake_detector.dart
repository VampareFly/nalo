// 摇一摇检测服务，供应用壳层触发运行环境选择入口。
import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// 监听加速度变化并在达到阈值后回调。
class ShakeDetector {
  ShakeDetector({this.gForceThreshold = 2.2});

  static const _earthGravity = 9.80665;

  final double gForceThreshold;
  StreamSubscription<AccelerometerEvent>? _subscription;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);

  /// 开始监听摇一摇事件。
  void start({required void Function() onShake}) {
    _subscription = accelerometerEventStream().listen((event) {
      final gForce = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      ) /
          _earthGravity;
      final now = DateTime.now();
      if (gForce < gForceThreshold ||
          now.difference(_lastShake) < const Duration(seconds: 2)) {
        return;
      }
      _lastShake = now;
      onShake();
    });
  }

  /// 停止监听并释放传感器资源。
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
