// 组合当前用户与首页业务数据，向新版首页提供单一状态入口。
// 接口确定后由 Repository 替换演示数据，View 无需随数据来源变化。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/auth/current_user_storage.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';

/// 加载首页聚合数据；当前结果数据用于接口接入前的 UI 联调。
final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final storage = await ref.watch(currentUserStorageProvider.future);
  final user = await storage.read();
  final userName = user?.fullName?.trim();
  final displayName = userName == null || userName.isEmpty ? 'Nalo' : userName;
  final initial = _firstVisibleCharacter(displayName);

  // TODO: <pf> 首页接口确定后，通过 HomeRepository 获取问候语、历史数量、最近结果和 Referral 配置。
  return HomeDashboardData(
    greeting: 'Good afternoon,',
    userName: displayName,
    userInitial: initial ?? 'N',
    totalTestCount: 7,
    cortisolResults: const [
      HomeRecentResult(
        type: HomeTestType.cortisol,
        monthLabel: 'August 2026',
        dateLabel: 'Aug 13',
        periodLabel: 'Night',
        valueLabel: '< 0.01 ng/ml',
        typicalRange: '<~1.3 ng/mL',
      ),
      HomeRecentResult(
        type: HomeTestType.cortisol,
        monthLabel: 'August 2026',
        dateLabel: 'Aug 13',
        periodLabel: 'Morning',
        valueLabel: '< 0.01 ng/ml',
        typicalRange: '~2–10 ng/mL',
      ),
      HomeRecentResult(
        type: HomeTestType.cortisol,
        monthLabel: 'August 2026',
        dateLabel: 'Aug 13',
        periodLabel: 'Night',
        valueLabel: '0.01–2 ng/ml',
        typicalRange: '<~1.3 ng/mL',
      ),
      HomeRecentResult(
        type: HomeTestType.cortisol,
        monthLabel: 'July 2026',
        dateLabel: 'Jul 13',
        periodLabel: 'Night',
        valueLabel: '2–10 ng/ml',
        typicalRange: '<~1.3 ng/mL',
      ),
    ],
    testosteroneResults: const [
      HomeRecentResult(
        type: HomeTestType.testosterone,
        monthLabel: 'August 2026',
        dateLabel: 'Aug 13',
        periodLabel: 'Morning',
        valueLabel: '< 0.01 ng/ml',
        typicalRange: '0.1–1.0 ng/mL',
      ),
      HomeRecentResult(
        type: HomeTestType.testosterone,
        monthLabel: 'August 2026',
        dateLabel: 'Aug 13',
        periodLabel: 'Night',
        valueLabel: '< 0.01 ng/ml',
        typicalRange: '0.1–1.0 ng/mL',
      ),
      HomeRecentResult(
        type: HomeTestType.testosterone,
        monthLabel: 'August 2026',
        dateLabel: 'Aug 13',
        periodLabel: 'Night',
        valueLabel: '0.1–1.0 ng/ml',
        typicalRange: '0.1–1.0 ng/mL',
      ),
    ],
    referralOffer: const HomeReferralOffer(
      title: 'Refer a friend — 10% off',
      description: 'You both save when they order.',
    ),
  );
});

String? _firstVisibleCharacter(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return null;
  return String.fromCharCode(normalized.runes.first).toUpperCase();
}
