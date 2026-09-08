// 检测接口层：只负责请求组装、响应解码和必要的协议一致性校验。
import 'package:dio/dio.dart';
import 'package:nalo/core/network/api_client.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';

/// 封装试纸检测相关 HTTP 接口，不保存页面状态或本地缓存。
class TestFlowService {
  const TestFlowService(this._client);
  final ApiClient _client;

  /// 获取结果等级和检测时间段的全局配置。
  Future<DetectionConfig> fetchConfig() async {
    final result = await _client.get<DetectionConfig>(
      '/api/v1/app/configs/list',
      decoder: DetectionConfig.fromJson,
    );
    if (result == null) {
      throw const ResponseFormatException('Detection config data is empty.');
    }
    return result;
  }

  /// 获取指定检测类型的结果；filter 为空时请求完整结果数据。
  Future<DetectionResult> fetchResult({
    required DetectionType type,
    String? filter,
  }) async {
    final result = await _client.get<DetectionResult>(
      '/api/v1/app/detections/result',
      queryParameters: {'detection_type': type.apiValue, 'filter': ?filter},
      decoder: DetectionResult.fromJson,
    );
    if (result == null) {
      throw const ResponseFormatException('Detection result data is empty.');
    }
    return result;
  }

  /// 以 multipart/form-data 上传试纸照片并返回服务端识别区间。
  Future<DetectionAnalysis> analyze({
    required DetectionType type,
    required String imagePath,
  }) async {
    final result = await _client.post<DetectionAnalysis>(
      '/api/v1/app/detections',
      data: FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last,
        ),
        'detection_type': type.apiValue,
      }),
      decoder: DetectionAnalysis.fromJson,
    );
    if (result == null) {
      throw const ResponseFormatException('Detection analysis data is empty.');
    }
    if (result.type != type) {
      throw const ResponseFormatException(
        'Detection type does not match the request.',
      );
    }
    return result;
  }

  /// 提交用户确认后的区间、采样日期和时段，并返回确认记录及庆祝页状态。
  Future<DetectionConfirmation> confirm({
    required DetectionType type,
    required String finalLevel,
    required DateTime? sampledAt,
    required String timePeriod,
    required int detectionId,
  }) async {
    final body = <String, dynamic>{
      'detection_type': type.apiValue,
      'final_level': finalLevel,
      'detection_time_periods': timePeriod,
      'detection_id': detectionId,
      if (sampledAt != null) 'sampled_at': _date(sampledAt),
    };
    final result = await _client.post<DetectionConfirmation>(
      '/api/v1/app/detections/confirm',
      data: body,
      decoder: DetectionConfirmation.fromJson,
    );
    if (result == null) {
      throw const ResponseFormatException(
        'Detection confirmation data is empty.',
      );
    }
    return result;
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
