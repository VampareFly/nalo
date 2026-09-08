// 检测数据仓库：协调远端接口与本地配置缓存，为 Provider 提供稳定的数据入口。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/core/network/api_providers.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';
import 'package:nalo/features/test_flow/services/test_flow_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统一管理检测配置缓存、图片识别、结果确认及结果读取。
class TestFlowRepository {
  const TestFlowRepository(this._service, this._preferences);

  static const _configKey = 'detection_config_v1';
  final TestFlowService _service;
  final SharedPreferences _preferences;

  /// 优先读取本地缓存，缓存缺失或损坏时返回随 App 发布的兜底配置。
  DetectionConfig readConfig() {
    final cached = _preferences.getString(_configKey);
    if (cached == null) return DetectionConfig.fallback;
    try {
      return DetectionConfig.fromEncoded(cached);
    } catch (_) {
      _preferences.remove(_configKey);
      return DetectionConfig.fallback;
    }
  }

  /// 拉取最新配置并在成功后覆盖本地缓存。
  Future<DetectionConfig> refreshConfig() async {
    final config = await _service.fetchConfig();
    await _preferences.setString(_configKey, config.encode());
    return config;
  }

  /// 获取进入检测前展示的最近三次记录。
  Future<DetectionResult> recent(DetectionType type) =>
      _service.fetchResult(type: type, filter: 'last_n_tests');

  /// 获取完成检测后的完整结果页数据。
  Future<DetectionResult> fullResult(DetectionType type) =>
      _service.fetchResult(type: type);

  /// 上传试纸图片并读取服务端识别结果。
  Future<DetectionAnalysis> analyze({
    required DetectionType type,
    required String imagePath,
  }) => _service.analyze(type: type, imagePath: imagePath);

  /// 提交用户最终确认的检测信息。
  Future<DetectionConfirmation> confirm({
    required DetectionType type,
    required String finalLevel,
    required DateTime? sampledAt,
    required String timePeriod,
    required int detectionId,
  }) => _service.confirm(
    type: type,
    finalLevel: finalLevel,
    sampledAt: sampledAt,
    timePeriod: timePeriod,
    detectionId: detectionId,
  );
}

/// 提供当前登录业务域可用的检测仓库实例。
final testFlowRepositoryProvider = FutureProvider<TestFlowRepository>((
  ref,
) async {
  final client = await ref.watch(businessApiClientProvider.future);
  final preferences = await SharedPreferences.getInstance();
  return TestFlowRepository(TestFlowService(client), preferences);
});
