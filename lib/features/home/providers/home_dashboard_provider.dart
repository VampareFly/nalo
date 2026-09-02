// 分别管理首页网络数据与当前用户快照，再组合为单一展示状态。
// 用户或 Referral 变化只重新组合本地数据，不触发首页网络请求。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';
import 'package:nalo/features/home/models/home_index_data.dart';
import 'package:nalo/features/home/repositories/home_repository.dart';
import 'package:nalo/features/onboarding/models/shopify_backend_auth_models.dart';
import 'package:nalo/features/test_flow/models/test_flow_models.dart';
import 'package:nalo/features/test_flow/providers/recent_tests_cache_provider.dart';

const _fallbackGreeting = 'Hello,';

/// 请求首页聚合数据；失败时返回空值供页面降级展示。
final homeIndexProvider = FutureProvider<HomeIndexData?>((ref) async {
  try {
    final repository = await ref.watch(homeRepositoryProvider.future);
    final data = await repository.fetchIndex();
    _updateRecentCache(ref, data);
    return data;
  } catch (_) {
    // 首页聚合接口失败时保留 Scan、Profile 和 Shop 等入口。
    return null;
  }
});

/// 组合用户快照与首页网络数据，不在用户变更时重新请求接口。
final homeDashboardProvider = Provider<AsyncValue<HomeDashboardData>>((ref) {
  final user = ref.watch(currentUserSnapshotProvider).value;
  final indexData = ref.watch(homeIndexProvider);
  final displayName = _displayName(user);
  final initial = _firstVisibleCharacter(displayName);

  return indexData.whenData(
    (data) => HomeDashboardData(
      greeting: _greetingFrom(data),
      userName: displayName,
      userInitial: initial ?? 'N',
      hasIndexData: data != null,
      totalTestCount: data?.historyTotal ?? 0,
      cortisolResults: _resultsFor(data, HomeTestType.cortisol),
      testosteroneResults: _resultsFor(data, HomeTestType.testosterone),
      referralOffer: _referralOffer(user),
    ),
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
    advocateRewardType: card.rewardsAdvocate?.rewardType,
    advocateRewardValue: card.rewardsAdvocate?.rewardValue,
    advocateRewardUnit: card.rewardsAdvocate?.rewardUnit,
    friendRewardType: card.rewardsFriend?.rewardType,
    friendRewardValue: card.rewardsFriend?.rewardValue,
    friendRewardUnit: card.rewardsFriend?.rewardUnit,
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
