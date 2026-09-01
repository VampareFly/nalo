// 渲染首页业务卡片，并统一处理 Section、Item 和入口曝光。
// HomePage 传入当前可见状态与曝光周期，路由点击继续交给容器。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nalo/core/analytics/analytics.dart';
import 'package:nalo/features/home/models/home_dashboard_data.dart';
import 'package:nalo/features/home/providers/home_dashboard_provider.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _blue = Color(0xFF008BC7);
const _ink = Color(0xFF1A2433);
const _muted = Color(0xFF667085);
const _surface = Color(0xFFFFFFFF);
const _softSurface = Color(0xFFF5F2EE);
const _yellow = Color(0xFFFDDA7C);
const _visibleFraction = 0.1;

/// 新版首页内容，消费聚合数据并将页面级操作交给 HomePage。
class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({
    super.key,
    required this.isActive,
    required this.exposureCycle,
    required this.onProfilePressed,
    required this.onScanPressed,
    required this.onHistoryPressed,
    required this.onReferralPressed,
  });

  /// 当前 Home Tab 是否实际可见。
  final bool isActive;

  /// Home 每次重新可见时递增，用于开启新曝光周期。
  final int exposureCycle;
  final VoidCallback onProfilePressed;
  final ValueChanged<int> onScanPressed;
  final ValueChanged<int> onHistoryPressed;
  final VoidCallback onReferralPressed;

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  final Set<String> _viewedSections = {};
  final Set<String> _viewedItems = {};
  final Set<String> _viewedEntries = {};

  @override
  void didUpdateWidget(covariant HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exposureCycle != widget.exposureCycle ||
        (oldWidget.isActive && !widget.isActive)) {
      _clearExposureState();
    }
  }

  void _clearExposureState() {
    _viewedSections.clear();
    _viewedItems.clear();
    _viewedEntries.clear();
  }

  void _handleSectionVisibility(
    HomeTestType type,
    int itemCount,
    int position,
    double visibleFraction,
  ) {
    if (!widget.isActive || visibleFraction < _visibleFraction) return;
    final detectionType = _analyticsDetectionType(type);
    final key = '${AnalyticsPageName.tabHome.value}:${detectionType.value}';
    if (!_viewedSections.add(key)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultSectionView,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.tabHome.value,
          AnalyticsEventProperty.detectionType: detectionType.value,
          AnalyticsEventProperty.itemCount: itemCount,
          AnalyticsEventProperty.position: position,
        },
      ),
    );
  }

  void _handleItemVisibility(
    HomeRecentResult result,
    int position,
    double visibleFraction,
  ) {
    if (!widget.isActive || visibleFraction < _visibleFraction) return;
    final detectionType = _analyticsDetectionType(result.type);
    final testId = result.id.toString();
    final key =
        '${AnalyticsPageName.tabHome.value}:${detectionType.value}:$testId';
    if (!_viewedItems.add(key)) return;
    unawaited(
      ref.report(
        AnalyticsEvent.testResultItemView,
        properties: {
          AnalyticsEventProperty.pageName: AnalyticsPageName.tabHome.value,
          AnalyticsEventProperty.testId: testId,
          AnalyticsEventProperty.detectionType: detectionType.value,
          AnalyticsEventProperty.position: position,
          AnalyticsEventProperty.date: result.dateLabel,
          AnalyticsEventProperty.timePeriod: result.periodLabel,
          AnalyticsEventProperty.value: result.value,
          AnalyticsEventProperty.unit: result.unit,
          AnalyticsEventProperty.typicalRange: result.typicalRange,
        },
      ),
    );
  }

  void _handleEntryVisibility(
    String key,
    AnalyticsEvent event,
    Map<AnalyticsEventProperty, Object> properties,
    double visibleFraction,
  ) {
    if (!widget.isActive || visibleFraction < _visibleFraction) return;
    if (!_viewedEntries.add(key)) return;
    unawaited(ref.report(event, properties: properties));
  }

  AnalyticsDetectionType _analyticsDetectionType(HomeTestType type) {
    return switch (type) {
      HomeTestType.cortisol => AnalyticsDetectionType.cortisol,
      HomeTestType.testosterone => AnalyticsDetectionType.testosterone,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(homeDashboardProvider);
    return Column(
      children: [
        dashboard.maybeWhen(
          data: (data) => _HomeTopBar(
            initial: data.userInitial,
            onProfilePressed: widget.onProfilePressed,
          ),
          orElse: () => _HomeTopBar(
            initial: 'N',
            onProfilePressed: widget.onProfilePressed,
          ),
        ),
        Expanded(
          child: dashboard.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: _blue)),
            error: (_, _) => _HomeLoadError(
              onRetry: () => ref.invalidate(homeIndexProvider),
            ),
            data: (data) => _HomeDashboardBody(
              data: data,
              isActive: widget.isActive,
              exposureCycle: widget.exposureCycle,
              onScanPressed: () => widget.onScanPressed(
                data.hasIndexData ? data.totalTestCount : -1,
              ),
              onHistoryPressed: () => widget.onHistoryPressed(
                data.hasIndexData ? data.totalTestCount : -1,
              ),
              onReferralPressed: widget.onReferralPressed,
              onSectionVisibility: _handleSectionVisibility,
              onItemVisibility: _handleItemVisibility,
              onEntryVisibility: _handleEntryVisibility,
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
                child: Text(
                  'nalo',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 26,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                      child: Text(
                        initial,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
    required this.isActive,
    required this.exposureCycle,
    required this.onScanPressed,
    required this.onHistoryPressed,
    required this.onReferralPressed,
    required this.onSectionVisibility,
    required this.onItemVisibility,
    required this.onEntryVisibility,
  });

  final HomeDashboardData data;
  final bool isActive;
  final int exposureCycle;
  final VoidCallback onScanPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onReferralPressed;
  final void Function(HomeTestType, int, int, double) onSectionVisibility;
  final void Function(HomeRecentResult, int, double) onItemVisibility;
  final void Function(
    String,
    AnalyticsEvent,
    Map<AnalyticsEventProperty, Object>,
    double,
  )
  onEntryVisibility;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Text(
          data.greeting,
          style: const TextStyle(
            color: Color(0xFF9FA89E),
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          data.userName,
          style: const TextStyle(
            color: _ink,
            fontSize: 30,
            height: 36 / 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        _TakeTestCard(onPressed: onScanPressed),
        _ReminderCard(
          exposureCycle: exposureCycle,
          isActive: isActive,
          onVisibilityChanged: (fraction) => onEntryVisibility(
            'notification-enable',
            AnalyticsEvent.notificationEnableView,
            {AnalyticsEventProperty.pageName: AnalyticsPageName.tabHome.value},
            fraction,
          ),
        ),
        const SizedBox(height: 20),
        _Exposure(
          keyName: 'history-entry',
          exposureCycle: exposureCycle,
          onVisibilityChanged: (fraction) => onEntryVisibility(
            'history-entry',
            AnalyticsEvent.testHistoryEntryView,
            {
              AnalyticsEventProperty.pageName: AnalyticsPageName.tabHome.value,
              AnalyticsEventProperty.totalTestCount: data.hasIndexData
                  ? data.totalTestCount
                  : -1,
            },
            fraction,
          ),
          child: _HistoryCard(
            totalCount: data.totalTestCount,
            onPressed: onHistoryPressed,
          ),
        ),
        if (data.cortisolResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ResultsCard(
            type: HomeTestType.cortisol,
            results: data.cortisolResults,
            sectionPosition: 1,
            exposureCycle: exposureCycle,
            onSectionVisibility: onSectionVisibility,
            onItemVisibility: onItemVisibility,
          ),
        ],
        if (data.testosteroneResults.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ResultsCard(
            type: HomeTestType.testosterone,
            results: data.testosteroneResults,
            sectionPosition: data.cortisolResults.isEmpty ? 1 : 2,
            exposureCycle: exposureCycle,
            onSectionVisibility: onSectionVisibility,
            onItemVisibility: onItemVisibility,
          ),
        ],
        if (data.referralOffer case final offer?) ...[
          const SizedBox(height: 20),
          _Exposure(
            keyName: 'referral',
            exposureCycle: exposureCycle,
            onVisibilityChanged: (fraction) =>
                onEntryVisibility('referral', AnalyticsEvent.referralView, {
                  AnalyticsEventProperty.pageName:
                      AnalyticsPageName.tabHome.value,
                  // TODO: <pf> 服务端提供结构化折扣比例后替换固定值 10。
                  AnalyticsEventProperty.discountPercent: 10,
                  AnalyticsEventProperty.url: offer.actionUrl,
                }, fraction),
            child: _ReferralCard(offer: offer, onPressed: onReferralPressed),
          ),
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
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'READY?',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a test.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Saliva strip · 15 minutes · instant result',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 20 / 13,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _yellow,
                foregroundColor: _ink,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Scan your strip',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({
    required this.exposureCycle,
    required this.isActive,
    required this.onVisibilityChanged,
  });

  final int exposureCycle;
  final bool isActive;
  final ValueChanged<double> onVisibilityChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(appNotificationPermissionProvider);
    return permission.maybeWhen(
      data: (state) {
        if (state.isEnabled) return const SizedBox.shrink();
        return _Exposure(
          keyName: 'notification-enable',
          exposureCycle: exposureCycle,
          onVisibilityChanged: onVisibilityChanged,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _ActionCard(
              iconAsset: 'assets/icons/home_reminder.svg',
              showIconBackground: false,
              title: 'Turn on reminders',
              subtitle: 'Never miss a test window.',
              trailing: OutlinedButton(
                onPressed: isActive
                    ? () {
                        unawaited(
                          ref.report(
                            AnalyticsEvent.notificationEnableClick,
                            properties: {
                              AnalyticsEventProperty.pageName:
                                  AnalyticsPageName.tabHome.value,
                            },
                          ),
                        );
                        ref
                            .read(appNotificationPermissionProvider.notifier)
                            .openSettings();
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  side: const BorderSide(color: Color(0xFFD7D7D7)),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Enable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
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
      trailing: SvgPicture.asset(
        'assets/icons/home_chevron.svg',
        width: 18,
        height: 18,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.showIconBackground = true,
  });
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
                  decoration: BoxDecoration(
                    color: showIconBackground
                        ? _softSurface
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(iconAsset, width: 18, height: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
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
  const _ResultsCard({
    required this.type,
    required this.results,
    required this.sectionPosition,
    required this.exposureCycle,
    required this.onSectionVisibility,
    required this.onItemVisibility,
  });
  final HomeTestType type;
  final List<HomeRecentResult> results;
  final int sectionPosition;
  final int exposureCycle;
  final void Function(HomeTestType, int, int, double) onSectionVisibility;
  final void Function(HomeRecentResult, int, double) onItemVisibility;

  @override
  Widget build(BuildContext context) {
    final title = type == HomeTestType.cortisol
        ? 'LAST 3 TESTS · CORTISOL'
        : 'LAST 3 TESTS · TESTOSTERONE';
    return _Exposure(
      keyName: 'result-section-${type.name}',
      exposureCycle: exposureCycle,
      onVisibilityChanged: (fraction) =>
          onSectionVisibility(type, results.length, sectionPosition, fraction),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _softSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${results.length}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < results.length; index++) ...[
              _Exposure(
                keyName: 'result-item-${type.name}-${results[index].id}',
                exposureCycle: exposureCycle,
                onVisibilityChanged: (fraction) =>
                    onItemVisibility(results[index], index + 1, fraction),
                child: _ResultRow(result: results[index]),
              ),
              if (index < results.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});
  final HomeRecentResult result;

  @override
  Widget build(BuildContext context) {
    final accent = result.type == HomeTestType.cortisol
        ? const Color(0xFF8AB4CB)
        : const Color(0xFFF5C842);
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
                Text(
                  result.dateLabel,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.periodLabel,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.valueLabel,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Typical range',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
              Text(
                result.typicalRange,
                style: const TextStyle(
                  color: Color(0xFFB07D00),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
              SvgPicture.asset(
                'assets/icons/home_referral.svg',
                width: 24,
                height: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.description,
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      offer.buttonText,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              SvgPicture.asset(
                'assets/icons/home_referral_chevron.svg',
                width: 18,
                height: 18,
              ),
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
    return Center(
      child: TextButton(onPressed: onRetry, child: const Text('Try again')),
    );
  }
}

class _Exposure extends StatelessWidget {
  const _Exposure({
    required this.keyName,
    required this.exposureCycle,
    required this.onVisibilityChanged,
    required this.child,
  });

  final String keyName;
  final int exposureCycle;
  final ValueChanged<double> onVisibilityChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey<String>('home-$exposureCycle-$keyName'),
      onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
      child: child,
    );
  }
}
