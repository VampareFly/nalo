// 渲染新版首页的业务卡片与最近检测结果。
// HomePage 注入导航回调，本文件只负责布局、权限入口和数据状态展示。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';

const _blue = Color(0xFF008BC7);
const _ink = Color(0xFF1A2433);
const _muted = Color(0xFF667085);
const _surface = Color(0xFFFFFFFF);
const _softSurface = Color(0xFFF5F2EE);
const _yellow = Color(0xFFFDDA7C);

/// 新版首页内容，消费聚合数据并将页面级操作交给 HomePage。
class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({
    super.key,
    required this.onProfilePressed,
    required this.onScanPressed,
    required this.onHistoryPressed,
    required this.onReferralPressed,
  });

  final VoidCallback onProfilePressed;
  final VoidCallback onScanPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onReferralPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(homeDashboardProvider);
    return Column(
      children: [
        dashboard.maybeWhen(
          data: (data) => _HomeTopBar(initial: data.userInitial, onProfilePressed: onProfilePressed),
          orElse: () => _HomeTopBar(initial: 'N', onProfilePressed: onProfilePressed),
        ),
        Expanded(
          child: dashboard.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _blue)),
            error: (_, _) => _HomeLoadError(onRetry: () => ref.invalidate(homeDashboardProvider)),
            data: (data) => _HomeDashboardBody(
              data: data,
              onScanPressed: onScanPressed,
              onHistoryPressed: onHistoryPressed,
              onReferralPressed: onReferralPressed,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.initial, required this.onProfilePressed});

  final String initial;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xE6EDE8E0),
        border: Border(bottom: BorderSide(color: Color(0x1A1A2433))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text('nalo', style: TextStyle(color: _blue, fontSize: 26, height: 1, fontWeight: FontWeight.w800)),
              ),
              Material(
                color: _blue,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onProfilePressed,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Text(initial, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeDashboardBody extends StatelessWidget {
  const _HomeDashboardBody({
    required this.data,
    required this.onScanPressed,
    required this.onHistoryPressed,
    required this.onReferralPressed,
  });

  final HomeDashboardData data;
  final VoidCallback onScanPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onReferralPressed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Text(data.greeting, style: const TextStyle(color: Color(0xFF9FA89E), fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600)),
        Text(data.userName, style: const TextStyle(color: _ink, fontSize: 30, height: 36 / 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        _TakeTestCard(onPressed: onScanPressed),
        const _ReminderCard(),
        const SizedBox(height: 20),
        _HistoryCard(totalCount: data.totalTestCount, onPressed: onHistoryPressed),
        if (data.cortisolResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ResultsCard(type: HomeTestType.cortisol, results: data.cortisolResults),
        ],
        if (data.testosteroneResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ResultsCard(type: HomeTestType.testosterone, results: data.testosteroneResults),
        ],
        if (data.referralOffer case final offer?) ...[
          const SizedBox(height: 20),
          _ReferralCard(offer: offer, onPressed: onReferralPressed),
        ],
      ],
    );
  }
}

class _TakeTestCard extends StatelessWidget {
  const _TakeTestCard({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('READY?', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Take a test.', style: TextStyle(color: Colors.white, fontSize: 20, height: 1.2, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Saliva strip · 15 minutes · instant result', style: TextStyle(color: Colors.white, fontSize: 13, height: 20 / 13)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(backgroundColor: _yellow, foregroundColor: _ink, shape: const StadiumBorder()),
              child: const Text('Scan your strip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(appNotificationPermissionProvider);
    return permission.maybeWhen(
      data: (state) {
        if (state.isEnabled) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _ActionCard(
            iconAsset: 'assets/icons/home_reminder.svg',
            showIconBackground: false,
            title: 'Turn on reminders',
            subtitle: 'Never miss a test window.',
            trailing: OutlinedButton(
              onPressed: () => ref.read(appNotificationPermissionProvider.notifier).openSettings(),
              style: OutlinedButton.styleFrom(foregroundColor: _ink, side: const BorderSide(color: Color(0xFFD7D7D7)), shape: const StadiumBorder()),
              child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.totalCount, required this.onPressed});
  final int totalCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final noun = totalCount == 1 ? 'test' : 'tests';
    return _ActionCard(
      iconAsset: 'assets/icons/home_history.svg',
      title: 'Test history',
      subtitle: '$totalCount $noun total',
      onTap: onPressed,
      trailing: SvgPicture.asset('assets/icons/home_chevron.svg', width: 18, height: 18),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.iconAsset, required this.title, required this.subtitle, required this.trailing, this.onTap, this.showIconBackground = true});
  final String iconAsset;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool showIconBackground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: showIconBackground ? 40 : 18,
                height: showIconBackground ? 40 : 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: showIconBackground ? _softSurface : Colors.transparent, shape: BoxShape.circle),
                  child: Center(child: SvgPicture.asset(iconAsset, width: 18, height: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: _ink, fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13, height: 18 / 13)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.type, required this.results});
  final HomeTestType type;
  final List<HomeRecentResult> results;

  @override
  Widget build(BuildContext context) {
    final title = type == HomeTestType.cortisol ? 'LAST 3 TESTS · CORTISOL' : 'LAST 3 TESTS · TESTOSTERONE';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700))),
              Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: _softSurface, shape: BoxShape.circle),
                child: Text('${results.length}', style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < results.length; index++) ...[
            _ResultRow(result: results[index]),
            if (index < results.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});
  final HomeRecentResult result;

  @override
  Widget build(BuildContext context) {
    final accent = result.type == HomeTestType.cortisol ? const Color(0xFF8AB4CB) : const Color(0xFFF5C842);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 14, 16, 14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.dateLabel, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(result.periodLabel, style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(result.valueLabel, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text('Typical range', style: TextStyle(color: _muted, fontSize: 10)),
              Text(result.typicalRange, style: const TextStyle(color: Color(0xFFB07D00), fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.offer, required this.onPressed});
  final HomeReferralOffer offer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _yellow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SvgPicture.asset('assets/icons/home_referral.svg', width: 24, height: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.title, style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(offer.description, style: const TextStyle(color: _muted, fontSize: 13)),
                  ],
                ),
              ),
              SvgPicture.asset('assets/icons/home_referral_chevron.svg', width: 18, height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeLoadError extends StatelessWidget {
  const _HomeLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(child: TextButton(onPressed: onRetry, child: const Text('Try again')));
  }
}
