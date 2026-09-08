// 定义首页聚合接口的远端响应模型。
// Service 负责解码本模型，Provider 再转换为页面使用的 HomeDashboardData。

/// 首页接口返回的问候语。
class HomeIndexGreeting {
  const HomeIndexGreeting({required this.message, required this.type});

  final String message;
  final String type;

  /// 从首页接口响应中解析问候语。
  factory HomeIndexGreeting.fromJson(Object? raw) {
    final json = _map(raw);
    return HomeIndexGreeting(
      message: _string(json, 'message'),
      type: _string(json, 'type'),
    );
  }
}

/// 首页接口返回的一条最近检测结果。
class HomeIndexTestItem {
  const HomeIndexTestItem({
    required this.id,
    this.detectionId,
    required this.date,
    required this.timePeriod,
    required this.value,
    required this.unit,
    required this.typicalRange,
  });

  final int id;
  final int? detectionId;
  final String date;
  final String timePeriod;
  final String value;
  final String unit;
  final String typicalRange;

  /// 从首页接口响应中解析最近检测结果。
  factory HomeIndexTestItem.fromJson(Object? raw) {
    final json = _map(raw);
    return HomeIndexTestItem(
      id: _integer(json, 'id'),
      detectionId: _optionalInt(json, 'detection_id'),
      date: _string(json, 'date'),
      timePeriod: _string(json, 'time_period'),
      value: _string(json, 'value'),
      unit: _string(json, 'unit'),
      typicalRange: _string(json, 'typical_range'),
    );
  }
}

/// 首页接口按激素类型组织的一组最近检测结果。
class HomeIndexTestGroup {
  const HomeIndexTestGroup({required this.detectionType, required this.items});

  final String detectionType;
  final List<HomeIndexTestItem> items;

  /// 从首页接口响应中解析检测类型分组。
  factory HomeIndexTestGroup.fromJson(Object? raw) {
    final json = _map(raw);
    final list = json['list'];
    if (list is! List) throw const FormatException('Missing list.');
    return HomeIndexTestGroup(
      detectionType: _string(json, 'detection_type'),
      items: list.map(HomeIndexTestItem.fromJson).toList(growable: false),
    );
  }
}

/// 首页聚合接口完整 data 数据。
class HomeIndexData {
  const HomeIndexData({
    required this.greeting,
    required this.historyTotal,
    required this.lastTests,
  });

  final HomeIndexGreeting greeting;
  final int historyTotal;
  final List<HomeIndexTestGroup> lastTests;

  /// 从首页接口 data 字段解析聚合数据。
  factory HomeIndexData.fromJson(Object? raw) {
    final json = _map(raw);
    final history = json['history'];
    final lastTests = json['last_tests'];
    if (lastTests is! List) throw const FormatException('Missing last_tests.');
    return HomeIndexData(
      greeting: HomeIndexGreeting.fromJson(json['greeting']),
      historyTotal: history is Map
          ? _nonNegativeIntOrZero(Map<String, dynamic>.from(history), 'total')
          : 0,
      lastTests: lastTests.map(HomeIndexTestGroup.fromJson).toList(growable: false),
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
  if (value is! int) throw FormatException('Missing $key.');
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is int ? value : null;
}

int _nonNegativeIntOrZero(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is int && value >= 0 ? value : 0;
}
