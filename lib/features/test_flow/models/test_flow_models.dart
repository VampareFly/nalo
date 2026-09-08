// 试纸检测领域模型：统一承载配置、图片识别、历史记录和最终结果的数据解析。
import 'dart:convert';

/// 服务端支持的激素检测类型，并提供接口值与页面展示名称。
enum DetectionType {
  cortisol,
  testosterone;

  String get apiValue => name;
  String get label => this == cortisol ? 'Cortisol' : 'Testosterone';
}

/// 一次完整检测流程中的页面节点。
enum TestFlowStep {
  about,
  beforeStart,
  swab,
  dip,
  develop,
  capture,
  preview,
  confirm,
  milestone,
  result,
}

/// 计时步骤的运行状态。
enum TimerStatus { idle, running, paused, complete }

/// 图片检测接口需要由客户端专门处理的稳定业务错误。
enum DetectionAnalysisError { recognitionFailed, invalidControlLine }

/// 服务端配置中的单个可选项，value 用于提交，label 用于展示。
class DetectionOption {
  const DetectionOption({
    required this.value,
    required this.label,
    this.range = '',
    this.hint = '',
  });

  final String value;
  final String label;
  final String range;
  final String hint;

  factory DetectionOption.fromJson(Object? raw) {
    final json = _map(raw);
    return DetectionOption(
      value: _string(json, 'value'),
      label: _string(json, 'label'),
      range: json['range'] as String? ?? '',
      hint: json['hint'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
    'range': range,
    'hint': hint,
  };
}

/// 一组同类检测选项，例如结果等级或检测时间段。
class DetectionOptionGroup {
  const DetectionOptionGroup({
    required this.key,
    required this.title,
    required this.unit,
    required this.options,
  });

  final String key;
  final String title;
  final String unit;
  final List<DetectionOption> options;

  factory DetectionOptionGroup.fromJson(Object? raw) {
    final json = _map(raw);
    final rawOptions = json['options'];
    if (rawOptions is! List || rawOptions.isEmpty) {
      throw const FormatException('Missing detection options.');
    }
    return DetectionOptionGroup(
      key: _string(json, 'key'),
      title: _string(json, 'title'),
      unit: json['unit'] as String? ?? '',
      options: rawOptions.map(DetectionOption.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'unit': unit,
    'options': options.map((e) => e.toJson()).toList(),
  };
}

/// 检测模块的远端配置及 App 内置兜底配置。
class DetectionConfig {
  const DetectionConfig({
    required this.cortisol,
    required this.testosterone,
    required this.timePeriods,
  });

  final DetectionOptionGroup cortisol;
  final DetectionOptionGroup testosterone;
  final DetectionOptionGroup timePeriods;

  DetectionOptionGroup readingsFor(DetectionType type) =>
      type == DetectionType.cortisol ? cortisol : testosterone;

  factory DetectionConfig.fromJson(Object? raw) {
    final json = _map(raw);
    return DetectionConfig(
      cortisol: DetectionOptionGroup.fromJson(json['result_level_cortisol']),
      testosterone: DetectionOptionGroup.fromJson(
        json['result_level_testosterone'],
      ),
      timePeriods: DetectionOptionGroup.fromJson(
        json['detection_time_periods'],
      ),
    );
  }

  factory DetectionConfig.fromEncoded(String value) =>
      DetectionConfig.fromJson(jsonDecode(value));
  String encode() => jsonEncode({
    'result_level_cortisol': cortisol.toJson(),
    'result_level_testosterone': testosterone.toJson(),
    'detection_time_periods': timePeriods.toJson(),
  });

  // TODO: <pf> 每次正式发版前使用服务端最新 configs/list 数据更新 App 内置兜底配置。
  static const fallback = DetectionConfig(
    cortisol: DetectionOptionGroup(
      key: 'final_level',
      title: 'YOUR READING',
      unit: 'μg/dL',
      options: [
        DetectionOption(value: 'CRITICAL_LOW', label: '< 0.01 μg/dL'),
        DetectionOption(value: 'LOW', label: '0.01–2 μg/dL'),
        DetectionOption(value: 'NORMAL', label: '2–10 μg/dL'),
        DetectionOption(value: 'HIGH', label: '> 10 μg/dL'),
      ],
    ),
    testosterone: DetectionOptionGroup(
      key: 'final_level',
      title: 'YOUR READING',
      unit: 'ng/mL',
      options: [
        DetectionOption(value: 'CRITICAL_LOW', label: '< 0.01 ng/mL'),
        DetectionOption(value: 'LOW', label: '0.01–2 ng/mL'),
        DetectionOption(value: 'NORMAL', label: '2–10 ng/mL'),
        DetectionOption(value: 'HIGH', label: '> 10 ng/mL'),
      ],
    ),
    timePeriods: DetectionOptionGroup(
      key: 'detection_time_periods',
      title: 'TIME OF DAY',
      unit: '',
      options: [
        DetectionOption(
          value: 'morning',
          label: 'Morning',
          range: '6 AM – 12 PM',
          hint: 'Recommended · ~1h after waking',
        ),
        DetectionOption(
          value: 'afternoon',
          label: 'Afternoon',
          range: '12 – 6 PM',
        ),
        DetectionOption(
          value: 'night',
          label: 'Night',
          range: '6 PM – 12 AM',
          hint: 'Bedtime',
        ),
      ],
    ),
  );
}

/// 图片上传后服务端返回的识别结果。
class DetectionAnalysis {
  const DetectionAnalysis({
    required this.id,
    required this.type,
    required this.aiValue,
    required this.aiValueResultLevel,
    required this.detectionTimePeriod,
    required this.unit,
    required this.typicalRange,
  });

  final int id;
  final DetectionType type;
  final String aiValue;
  final String aiValueResultLevel;
  final String detectionTimePeriod;
  final String unit;
  final String typicalRange;

  factory DetectionAnalysis.fromJson(Object? raw) {
    final json = _map(raw);
    final matches = DetectionType.values.where(
      (e) => e.apiValue == _string(json, 'detection_type'),
    );
    final type = matches.isEmpty ? null : matches.first;
    if (type == null) throw const FormatException('Invalid detection type.');
    return DetectionAnalysis(
      id: _integer(json, 'detection_id'),
      type: type,
      aiValue: _string(json, 'ai_value'),
      aiValueResultLevel: _string(json, 'ai_value_result_level'),
      detectionTimePeriod: _string(json, 'detection_time_periods'),
      unit: _string(json, 'unit'),
      typicalRange: _string(_map(json['typical_range']), 'display'),
    );
  }
}

/// 用户确认检测结果后，服务端返回的确认记录和周期展示状态。
class DetectionConfirmation {
  const DetectionConfirmation({
    required this.confirmRecordId,
    required this.showPopup,
  });

  final int confirmRecordId;
  final bool showPopup;

  /// 从确认接口 data 中解析确认记录 ID 和庆祝页标识。
  factory DetectionConfirmation.fromJson(Object? raw) {
    final json = _map(raw);
    final showPopup = _integer(json, 'show_popup');
    if (showPopup != 0 && showPopup != 1) {
      throw const FormatException('Invalid show_popup.');
    }
    return DetectionConfirmation(
      confirmRecordId: _integer(json, 'confirm_record_id'),
      showPopup: showPopup == 1,
    );
  }
}

/// 最近一次检测列表中的摘要数据。
class RecentDetection {
  const RecentDetection({
    required this.id,
    this.detectionId,
    required this.date,
    required this.period,
    required this.value,
    required this.unit,
    required this.typicalRange,
  });
  final int id;
  final int? detectionId;
  final String date;
  final String period;
  final String value;
  final String unit;
  final String typicalRange;

  factory RecentDetection.fromJson(Object? raw) {
    final json = _map(raw);
    return RecentDetection(
      id: _integer(json, 'id'),
      detectionId: json['detection_id'] is int
          ? json['detection_id'] as int
          : null,
      date: _string(json, 'date'),
      period: _string(json, 'time_period'),
      value: _string(json, 'value'),
      unit: _string(json, 'unit'),
      typicalRange: _string(json, 'typical_range'),
    );
  }
}

/// 检测结果页所需的当前读数、说明和最近三次记录。
class DetectionResult {
  const DetectionResult({
    this.value,
    this.unit,
    this.testTime,
    this.typicalRange,
    this.infoTitle,
    this.infoContent,
    this.recent = const [],
  });
  final String? value;
  final String? unit;
  final String? testTime;
  final String? typicalRange;
  final String? infoTitle;
  final String? infoContent;
  final List<RecentDetection> recent;

  factory DetectionResult.fromJson(Object? raw) {
    final json = _map(raw);
    final reading = json['current_reading'] is Map
        ? _map(json['current_reading'])
        : const <String, dynamic>{};
    final range = json['typical_range'] is Map
        ? _map(json['typical_range'])
        : const <String, dynamic>{};
    final info = json['info'] is Map
        ? _map(json['info'])
        : const <String, dynamic>{};
    final recent = json['last_n_tests'];
    return DetectionResult(
      value: reading['value'] as String?,
      unit: reading['unit'] as String?,
      testTime: reading['test_time'] as String?,
      typicalRange: range['display'] as String?,
      infoTitle: info['title'] as String?,
      infoContent: info['content'] as String?,
      recent: recent is List
          ? recent.map(RecentDetection.fromJson).toList(growable: false)
          : const [],
    );
  }
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map) throw const FormatException('Expected an object.');
  return Map<String, dynamic>.from(raw);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('Missing $key.');
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Missing $key.');
  return value.toInt();
}
