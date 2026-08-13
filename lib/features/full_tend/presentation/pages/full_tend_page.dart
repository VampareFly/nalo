import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:nalo/features/full_tend/models/full_tend_month.dart';
import 'package:nalo/features/full_tend/providers/full_tend_provider.dart';
import 'package:nalo/features/home/presentation/widgets/medical_disclaimer_footer.dart';
import 'package:nalo/features/notifications/providers/notification_permission_provider.dart';

class FullTendPage extends ConsumerStatefulWidget {
  const FullTendPage({super.key});

  static const path = '/full-tend';

  @override
  ConsumerState<FullTendPage> createState() => _FullTendPageState();
}

class _FullTendPageState extends ConsumerState<FullTendPage> {
  late DateTime _selectedMonth;
  _TendType _selectedType = _TendType.cortisol;

  @override
  void initState() {
    super.initState();
    final months = ref.read(fullTendMonthsProvider);
    _selectedMonth = months.isEmpty ? DateTime.now() : months.first.month;
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
  }

  Future<void> _openNotificationSettings() async {
    // TODO: <pf> Schedule the next test reminder after notification delivery is implemented.
    await ref.read(notificationPermissionServiceProvider).openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final months = _selectedType == _TendType.cortisol
        ? ref.watch(fullTendMonthsProvider)
        : ref.watch(fullTendTestosteroneMonthsProvider);
    final month = months.where((item) => item.month.year == _selectedMonth.year && item.month.month == _selectedMonth.month).firstOrNull ??
        FullTendMonth(month: _selectedMonth, readings: const []);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 44),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF606064), padding: EdgeInsets.zero),
                      icon: const Icon(Icons.chevron_left, size: 22),
                      label: const Text('Back', style: TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Full trend',
                      style: TextStyle(fontFamily: 'Times New Roman', fontStyle: FontStyle.italic, fontSize: 26, height: 1),
                    ),
                    const SizedBox(height: 28),
                    _TendTypeSelector(
                      selectedType: _selectedType,
                      onSelected: (type) => setState(() => _selectedType = type),
                    ),
                    const SizedBox(height: 22),
                    _MonthSelector(month: _selectedMonth, onPrevious: () => _changeMonth(-1), onNext: () => _changeMonth(1)),
                    const SizedBox(height: 18),
                    _TrendCard(month: month, type: _selectedType),
                    const SizedBox(height: 24),
                    Text(
                      'READINGS  ·  ${DateFormat('MMMM yyyy').format(_selectedMonth).toUpperCase()}',
                      style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, letterSpacing: 1.3),
                    ),
                    const SizedBox(height: 16),
                    if (month.hasTimingWarning) ...[
                      const _TimingWarningCard(),
                      const SizedBox(height: 18),
                    ],
                    if (month.isComplete)
                      _CompletedReport(month: month, type: _selectedType)
                    else
                      _PendingReport(
                        month: month,
                        type: _selectedType,
                        onRemindPressed: () => unawaited(_openNotificationSettings()),
                      ),
                    const SizedBox(height: 46),
                    const MedicalDisclaimerFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TendType {
  cortisol(label: 'Cortisol', unit: 'ng/mL', maximumValue: 8, referenceLabel: 'SHADED BAND = MORNING REFERENCE (1.0–7.5 NG/ML)'),
  testosterone(
    label: 'Testosterone',
    unit: 'ng/dL',
    maximumValue: 1000,
    referenceLabel: 'SHADED BAND = MORNING REFERENCE (300–900 NG/DL)',
  );

  const _TendType({required this.label, required this.unit, required this.maximumValue, required this.referenceLabel});

  final String label;
  final String unit;
  final double maximumValue;
  final String referenceLabel;
}

class _TendTypeSelector extends StatelessWidget {
  const _TendTypeSelector({required this.selectedType, required this.onSelected});

  final _TendType selectedType;
  final ValueChanged<_TendType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(
          label: _TendType.cortisol.label,
          selected: selectedType == _TendType.cortisol,
          onPressed: () => onSelected(_TendType.cortisol),
        ),
        const SizedBox(width: 8),
        _Pill(
          label: _TendType.testosterone.label,
          selected: selectedType == _TendType.testosterone,
          onPressed: () => onSelected(_TendType.testosterone),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF050505) : Colors.white,
      shape: StadiumBorder(side: selected ? BorderSide.none : const BorderSide(color: Color(0xFFD8D8DC))),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFFC5C5C8), fontSize: 12)),
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onPrevious, required this.onNext});

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundArrow(icon: Icons.chevron_left, onPressed: onPrevious),
        Text(DateFormat('MMMM yyyy').format(month), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        _RoundArrow(icon: Icons.chevron_right, onPressed: onNext),
      ],
    );
  }
}

class _RoundArrow extends StatelessWidget {
  const _RoundArrow({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 18), constraints: const BoxConstraints.tightFor(width: 40, height: 40)),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.month, required this.type});

  final FullTendMonth month;
  final _TendType type;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.referenceLabel,
            style: const TextStyle(color: Color(0xFF77777A), fontSize: 9, height: 1.45, letterSpacing: 1.1),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: month.readings.isEmpty
                ? const _EmptyChart()
                : CustomPaint(
                    painter: _FullTendChartPainter(
                      month.readings.take(FullTendMonth.maximumReadings).toList(),
                      maximumValue: type.maximumValue,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (month.average != null)
            Row(
              children: [
                const Icon(Icons.circle, color: Color(0xFFA9B5F4), size: 11),
                const SizedBox(width: 8),
                Text('${type.label} avg', style: const TextStyle(color: Color(0xFF77777A), fontSize: 11)),
                const SizedBox(width: 7),
                Text('${month.average!.toStringAsFixed(1)} ${type.unit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('empty-chart'),
      decoration: BoxDecoration(color: const Color(0xFFA9B5F4).withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No readings yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 7),
          Text('Complete your first test to start this month’s trend.', style: TextStyle(color: Color(0xFF77777A), fontSize: 10)),
        ],
      ),
    );
  }
}

class _PendingReport extends StatelessWidget {
  const _PendingReport({required this.month, required this.type, required this.onRemindPressed});

  final FullTendMonth month;
  final _TendType type;
  final VoidCallback onRemindPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pending-report'),
      children: [
        for (final reading in month.readings) ...[
          _ReadingCard(reading: reading, type: type),
          const SizedBox(height: 12),
        ],
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${month.remainingCount} ${month.remainingCount == 1 ? 'more reading' : 'readings'} to unlock your full report.',
                style: const TextStyle(color: Color(0xFF77777A), fontSize: 11),
              ),
              const SizedBox(height: 18),
              Text('NEXT: TEST ${month.completedCount + 1} OF 3', style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Text(
                month.completedCount == 0 ? 'Start with your first morning test' : 'Test tomorrow morning · aim ~8am',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 7),
              const Text('Space tests 2 days apart for best trend data', style: TextStyle(color: Color(0xFF77777A), fontSize: 11, height: 1.4)),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRemindPressed,
                icon: const Icon(Icons.notifications_none, size: 16),
                label: const Text('Remind me'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8FA4EE), side: const BorderSide(color: Color(0xFFA9B9F5))),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.reading, required this.type});

  final FullTendReading reading;
  final _TendType type;

  @override
  Widget build(BuildContext context) {
    final isNormal = reading.status == FullTendRangeStatus.normal;
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFFA9B5F4), size: 9),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${reading.value.toStringAsFixed(1)} ${type.unit}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 5),
                Text(
                  '${type.label} · ${DateFormat('MMM d').format(reading.testedAt)} · ${reading.periodLabel} · ${DateFormat('h:mm a').format(reading.testedAt)}',
                  style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, height: 1.35),
                ),
              ],
            ),
          ),
          _StatusBadge(isNormal: isNormal),
        ],
      ),
    );
  }
}

class _TimingWarningCard extends StatelessWidget {
  const _TimingWarningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('timing-warning'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EF),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFFFD39C)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⏰ Heads up on timing', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text(
            'Your tests were taken at different times. For the most comparable trend, try to test at the same time each day.',
            style: TextStyle(color: Color(0xFF77777A), fontSize: 11, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _CompletedReport extends StatelessWidget {
  const _CompletedReport({required this.month, required this.type});

  final FullTendMonth month;
  final _TendType type;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('completed-report'),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('READINGS INCLUDED', style: TextStyle(color: Color(0xFF77777A), fontSize: 9, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              for (var index = 0; index < month.readings.length; index++) ...[
                _IncludedReading(reading: month.readings[index], type: type),
                if (index < month.readings.length - 1) const Divider(height: 22, color: Color(0xFFE8E8EA)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WHAT THIS SCORE MAY MEAN', style: TextStyle(color: Color(0xFF77777A), fontSize: 9, letterSpacing: 1.2)),
              const SizedBox(height: 18),
              Text(
                'Your average ${type.label.toLowerCase()} is within the normal morning range. Keep your sleep, exercise, and meal timing consistent.',
                style: const TextStyle(color: Color(0xFF77777A), fontSize: 14, height: 1.55),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SubscriptionCard(),
      ],
    );
  }
}

class _IncludedReading extends StatelessWidget {
  const _IncludedReading({required this.reading, required this.type});

  final FullTendReading reading;
  final _TendType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${reading.value.toStringAsFixed(1)} ${type.unit}', style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 5),
              Text(
                '${DateFormat('MMM d, h:mm a').format(reading.testedAt)} · ${reading.periodLabel}',
                style: const TextStyle(color: Color(0xFF77777A), fontSize: 9),
              ),
            ],
          ),
        ),
        _StatusBadge(isNormal: reading.status == FullTendRangeStatus.normal),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isNormal});

  final bool isNormal;

  @override
  Widget build(BuildContext context) {
    final foreground = isNormal ? const Color(0xFF269C57) : const Color(0xFFD73535);
    final background = isNormal ? const Color(0xFFF0FFF5) : const Color(0xFFFFF3F3);
    final border = isNormal ? const Color(0xFFBDF2CE) : const Color(0xFFFFC4C4);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Text(isNormal ? 'Normal range' : 'On the high side', style: TextStyle(color: foreground, fontSize: 10)),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: const Color(0xFFF0EFF4), borderRadius: BorderRadius.circular(27)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SUBSCRIBE & SAVE', style: TextStyle(color: Color(0xFF90A4EE), fontSize: 9, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          const Text(r'$13.50/month', style: TextStyle(fontFamily: 'Times New Roman', fontStyle: FontStyle.italic, fontSize: 21)),
          const SizedBox(height: 8),
          const Text('Save 10% on all kits · Priority results · Monthly PDF report · AI coaching', style: TextStyle(color: Color(0xFF77777A), fontSize: 11, height: 1.35)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              // TODO: <pf> Open the subscription flow after it is implemented.
              BotToast.showText(text: 'Subscription is coming soon', align: Alignment.center);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF050505), foregroundColor: Colors.white),
            child: const Text('Get 10% off →'),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(22)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}

class _FullTendChartPainter extends CustomPainter {
  const _FullTendChartPainter(this.readings, {required this.maximumValue});

  final List<FullTendReading> readings;
  final double maximumValue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(maximumValue > 8 ? 42 : 34, 8, size.width - 3, size.height - 26);
    final gridPaint = Paint()
      ..color = const Color(0xFFE3E4E8)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: Color(0xFF77777A), fontSize: 9);

    canvas.drawRect(
      Rect.fromLTRB(
        rect.left,
        _valueY(maximumValue == 8 ? 7.5 : 900, rect),
        rect.right,
        _valueY(maximumValue == 8 ? 1 : 300, rect),
      ),
      Paint()..color = const Color(0xFFA9B5F4).withValues(alpha: 0.045),
    );

    for (var index = 0; index <= 4; index++) {
      final y = rect.top + rect.height * index / 4;
      _dashedLine(canvas, Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      final value = maximumValue - maximumValue * index / 4;
      _text(
        canvas,
        value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1),
        Offset(0, y - 6),
        rect.left - 8,
        labelStyle,
        TextAlign.right,
      );
    }
    _dashedLine(canvas, rect.topLeft, rect.bottomLeft, gridPaint);
    _dashedLine(canvas, rect.topRight, rect.bottomRight, gridPaint);

    final points = <Offset>[];
    for (var index = 0; index < readings.length; index++) {
      final x = readings.length == 1 ? rect.center.dx : rect.left + rect.width * index / (readings.length - 1);
      points.add(Offset(x, _valueY(readings[index].value, rect)));
      final align = index == 0 ? TextAlign.left : index == readings.length - 1 ? TextAlign.right : TextAlign.center;
      _text(canvas, DateFormat('MMM d').format(readings[index].testedAt), Offset(x - 28, rect.bottom + 7), 56, labelStyle, align);
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFA9B5F4)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    for (final point in points) {
      canvas.drawCircle(point, 4.5, Paint()..color = const Color(0xFFA9B5F4));
    }
  }

  double _valueY(double value, Rect rect) => rect.bottom - rect.height * (value.clamp(0, maximumValue).toDouble() / maximumValue);

  void _text(Canvas canvas, String text, Offset offset, double width, TextStyle style, TextAlign align) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  void _dashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 3.0;
    const gap = 4.0;
    final distance = (end - start).distance;
    final direction = (end - start) / distance;
    for (var drawn = 0.0; drawn < distance; drawn += dash + gap) {
      final dashEnd = (drawn + dash).clamp(0, distance).toDouble();
      canvas.drawLine(start + direction * drawn, start + direction * dashEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullTendChartPainter oldDelegate) =>
      oldDelegate.maximumValue != maximumValue || !listEquals(oldDelegate.readings, readings);
}
