// 定义检测历史接口模型与筛选类型。
// Service 负责解码，ViewModel 负责分页合并，页面只消费稳定的展示字段。

/// 检测历史支持的服务端筛选类型。
enum TestHistoryFilter {
  all('all', 'All'),
  cortisol('cortisol', 'Cortisol'),
  testosterone('testosterone', 'Testosterone');

  const TestHistoryFilter(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// 历史页顶部各筛选项的结果数量。
class TestHistoryCounts {
  const TestHistoryCounts({
    required this.all,
    required this.cortisol,
    required this.testosterone,
  });

  const TestHistoryCounts.empty() : all = 0, cortisol = 0, testosterone = 0;

  final int all;
  final int cortisol;
  final int testosterone;

  /// 返回指定筛选项对应的总数。
  int forFilter(TestHistoryFilter filter) => switch (filter) {
    TestHistoryFilter.all => all,
    TestHistoryFilter.cortisol => cortisol,
    TestHistoryFilter.testosterone => testosterone,
  };

  /// 从历史接口响应中解析数量。
  factory TestHistoryCounts.fromJson(Map<String, dynamic> json) {
    return TestHistoryCounts(
      all: _requiredInt(json, 'all'),
      cortisol: _requiredInt(json, 'cortisol'),
      testosterone: _requiredInt(json, 'testosterone'),
    );
  }
}

/// 一条检测历史结果。
class TestHistoryItem {
  const TestHistoryItem({
    required this.id,
    required this.date,
    required this.timePeriod,
    required this.type,
    required this.value,
    required this.unit,
    required this.typicalRange,
  });

  final int id;
  final String date;
  final String timePeriod;
  final TestHistoryFilter type;
  final String value;
  final String unit;
  final String typicalRange;

  /// 返回包含单位的检测值文案。
  String get valueLabel => unit.isEmpty ? value : '$value $unit';

  /// 从历史接口响应中解析单条结果。
  factory TestHistoryItem.fromJson(Map<String, dynamic> json) {
    final typeValue = _requiredString(json, 'detection_type');
    final type = TestHistoryFilter.values
        .where((item) => item.apiValue == typeValue)
        .firstOrNull;
    if (type == null || type == TestHistoryFilter.all) {
      throw const FormatException('Invalid history detection_type.');
    }
    return TestHistoryItem(
      id: _requiredInt(json, 'id'),
      date: _requiredString(json, 'date'),
      timePeriod: _requiredString(json, 'time_period'),
      type: type,
      value: _requiredString(json, 'value'),
      unit: _requiredString(json, 'unit'),
      typicalRange: _requiredString(json, 'typical_range'),
    );
  }
}

/// 服务端按月份返回的一组检测历史。
class TestHistoryGroup {
  const TestHistoryGroup({
    required this.monthLabel,
    required this.sortKey,
    required this.items,
  });

  final String monthLabel;
  final String sortKey;
  final List<TestHistoryItem> items;

  /// 创建追加结果后的月份分组。
  TestHistoryGroup copyWith({List<TestHistoryItem>? items}) => TestHistoryGroup(
    monthLabel: monthLabel,
    sortKey: sortKey,
    items: items ?? this.items,
  );

  /// 从历史接口响应中解析月份分组。
  factory TestHistoryGroup.fromJson(Map<String, dynamic> json) =>
      TestHistoryGroup(
        monthLabel: _requiredString(json, 'month_label'),
        sortKey: _requiredString(json, 'sort_key'),
        items: _requiredList(json, 'items')
            .map((item) => TestHistoryItem.fromJson(_map(item)))
            .toList(growable: false),
      );
}

/// 历史接口单页响应数据。
class TestHistoryPageData {
  const TestHistoryPageData({
    required this.counts,
    required this.hasMore,
    required this.nextEndDate,
    required this.groups,
  });

  final TestHistoryCounts counts;
  final bool hasMore;
  final String nextEndDate;
  final List<TestHistoryGroup> groups;

  /// 从历史接口 data 字段解析分页结果。
  factory TestHistoryPageData.fromJson(dynamic raw) {
    final json = _map(raw);
    final pagination = _map(json['pagination']);
    final hasMore = pagination['has_more'];
    if (hasMore is! bool) throw const FormatException('Invalid has_more.');
    final nextEndDate = _optionalString(pagination, 'next_end_date');
    if (hasMore && nextEndDate.isEmpty) {
      throw const FormatException('Missing next_end_date for next page.');
    }
    final groups = _requiredList(json, 'groups')
        .map((item) => TestHistoryGroup.fromJson(_map(item)))
        .toList(growable: false);
    return TestHistoryPageData(
      counts: TestHistoryCounts.fromJson(pagination),
      hasMore: hasMore,
      nextEndDate: nextEndDate,
      groups: groups,
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Expected a JSON object.');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('Invalid $key.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Invalid $key.');
}

String _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return '';
  if (value is String) return value;
  throw FormatException('Invalid $key.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Invalid $key.');
}
