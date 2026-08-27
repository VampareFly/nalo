// 定义新版首页聚合展示模型。
// Provider 负责提供服务端数据，首页 View 只按模型渲染和派发交互。

/// 首页支持的检测结果类型。
enum HomeTestType { cortisol, testosterone }

/// 首页最近检测模块使用的一条结果。
class HomeRecentResult {
  const HomeRecentResult({
    required this.id,
    required this.type,
    required this.monthLabel,
    required this.dateLabel,
    required this.periodLabel,
    required this.valueLabel,
    required this.value,
    required this.unit,
    required this.typicalRange,
  });

  final int id;
  final HomeTestType type;
  final String monthLabel;
  final String dateLabel;
  final String periodLabel;
  final String valueLabel;
  final String value;
  final String unit;
  final String typicalRange;
}

/// 首页邀请活动的展示数据。
class HomeReferralOffer {
  const HomeReferralOffer({required this.title, required this.description});

  final String title;
  final String description;
}

/// 首页一次渲染所需的聚合数据。
class HomeDashboardData {
  const HomeDashboardData({
    required this.greeting,
    required this.userName,
    required this.userInitial,
    required this.hasIndexData,
    required this.totalTestCount,
    required this.cortisolResults,
    required this.testosteroneResults,
    this.referralOffer,
  });

  final String greeting;
  final String userName;
  final String userInitial;

  /// 首页聚合接口是否成功，用于区分真实 0 和降级数据。
  final bool hasIndexData;
  final int totalTestCount;
  final List<HomeRecentResult> cortisolResults;
  final List<HomeRecentResult> testosteroneResults;
  final HomeReferralOffer? referralOffer;
}
