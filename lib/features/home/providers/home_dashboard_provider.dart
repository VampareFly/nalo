// 组合当前用户与首页聚合接口数据，向首页提供单一展示状态。
// 远端接口失败时保留用户信息和页面入口，并对检测内容统一降级。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';
import 'package:nalo/features/home/models/home_index_data.dart';
import 'package:nalo/features/home/repositories/home_repository.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';
import 'package:nalo/features/test_flow/providers/recent_tests_cache_provider.dart';

const _fallbackGreeting = 'Hello,';

/// 加载首页用户名、服务端问候语、检测总数和两类最近结果。
final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final user = ref.watch(currentUserSnapshotProvider).value;
  final repositoryFuture = ref.watch(homeRepositoryProvider.future);
  final displayName = _displayName(user);
  final initial = _firstVisibleCharacter(displayName);
  HomeIndexData? indexData;

  try {
    final repository = await repositoryFuture;
    indexData = await repository.fetchIndex();
    _updateRecentCache(ref, indexData);
  } catch (_) {
    // 首页聚合接口失败时只降级远端内容，Scan、Profile、Shop 等入口仍可使用。
  }

  return HomeDashboardData(
    greeting: _greetingFrom(indexData),
    userName: displayName,
    userInitial: initial ?? 'N',
    hasIndexData: indexData != null,
    totalTestCount: indexData?.historyTotal ?? 0,
    cortisolResults: _resultsFor(indexData, HomeTestType.cortisol),
    testosteroneResults: _resultsFor(indexData, HomeTestType.testosterone),
    referralOffer: _referralOffer(user),
  );
});

void _updateRecentCache(Ref ref, HomeIndexData data) {
  ref
      .read(recentTestsCacheProvider.notifier)
      .replaceFromHome(
        cortisol: _cachedResultsFor(data, 'cortisol'),
        testosterone: _cachedResultsFor(data, 'testosterone'),
      );
}

List<RecentDetection> _cachedResultsFor(HomeIndexData data, String type) {
  return data.lastTests
      .where((group) => group.detectionType == type)
      .expand((group) => group.items)
      .map(
        (item) => RecentDetection(
          id: item.id,
          date: item.date,
          period: item.timePeriod,
          value: item.value,
          unit: item.unit,
          typicalRange: item.typicalRange,
        ),
      )
      .toList(growable: false);
}

String _displayName(AppUserInfo? user) {
  final userName = user?.fullName?.trim();
  return userName == null || userName.isEmpty ? 'Nalo' : userName;
}

HomeReferralOffer? _referralOffer(AppUserInfo? user) {
  final card = user?.referralCard;
  if (card == null) return null;
  return HomeReferralOffer(
    title: card.title,
    description: card.description,
    buttonText: card.buttonText,
    actionUrl: card.actionUrl,
    shareText: card.shareText,
  );
}

List<HomeRecentResult> _resultsFor(HomeIndexData? data, HomeTestType type) {
  if (data == null) return const [];
  final apiType = type == HomeTestType.cortisol ? 'cortisol' : 'testosterone';
  final items = data.lastTests
      .where((group) => group.detectionType == apiType)
      .expand((group) => group.items);
  return items
      .map(
        (item) => HomeRecentResult(
          id: item.id,
          type: type,
          monthLabel: _monthLabel(item.date),
          dateLabel: item.date,
          periodLabel: item.timePeriod,
          valueLabel: '${item.value} ${item.unit}'.trim(),
          value: item.value,
          unit: item.unit,
          typicalRange: item.typicalRange,
        ),
      )
      .toList(growable: false);
}

String _greetingFrom(HomeIndexData? data) {
  final message = data?.greeting.message.trim() ?? '';
  return message.isEmpty ? _fallbackGreeting : message;
}

String _monthLabel(String date) {
  const months = {
    'Jan': 'January',
    'Feb': 'February',
    'Mar': 'March',
    'Apr': 'April',
    'May': 'May',
    'Jun': 'June',
    'Jul': 'July',
    'Aug': 'August',
    'Sep': 'September',
    'Oct': 'October',
    'Nov': 'November',
    'Dec': 'December',
  };
  final parts = date.trim().split(RegExp(r'\s+'));
  final abbreviation = parts.isEmpty ? null : parts.first;
  final month = months[abbreviation] ?? abbreviation ?? '';
  return '$month ${DateTime.now().year}'.trim();
}

String? _firstVisibleCharacter(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return null;
  return String.fromCharCode(normalized.runes.first).toUpperCase();
}
