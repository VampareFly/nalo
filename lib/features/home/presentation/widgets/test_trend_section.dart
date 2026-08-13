import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nalo/features/home/models/test_trend.dart';
import 'package:nalo/features/home/providers/test_trends_provider.dart';

class TestTrendSection extends ConsumerStatefulWidget {
  const TestTrendSection({super.key, required this.onFullPressed});

  final VoidCallback onFullPressed;

  @override
  ConsumerState<TestTrendSection> createState() => _TestTrendSectionState();
}

class _TestTrendSectionState extends ConsumerState<TestTrendSection> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final trends = ref.watch(testTrendsProvider);
    final selectedTrend = trends[_selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TREND',
          style: TextStyle(color: Color(0xFF77777A), fontSize: 10, height: 1, fontWeight: FontWeight.w500, letterSpacing: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var index = 0; index < trends.length; index++) ...[
              _TrendTypeButton(
                label: trends[index].label,
                isSelected: index == _selectedIndex,
                onPressed: () => setState(() => _selectedIndex = index),
              ),
              if (index < trends.length - 1) const SizedBox(width: 8),
            ],
            const Spacer(),
            OutlinedButton(
              onPressed: widget.onFullPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3E3E43),
                side: const BorderSide(color: Color(0xFFE2E3E8)),
                minimumSize: const Size(68, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Full →'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _TrendCard(key: ValueKey(selectedTrend.label), trend: selectedTrend),
        ),
      ],
    );
  }
}

class _TrendTypeButton extends StatelessWidget {
  const _TrendTypeButton({required this.label, required this.isSelected, required this.onPressed});

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF050505) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isSelected ? null : onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 82),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: isSelected ? null : Border.all(color: const Color(0xFFE2E3E8)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFC6C6CA),
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({super.key, required this.trend});

  final TestTrend trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trend.title,
            style: const TextStyle(
              color: Color(0xFF202023),
              fontFamily: 'Times New Roman',
              fontSize: 21,
              height: 1,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            trend.referenceLabel,
            style: const TextStyle(color: Color(0xFF77777A), fontSize: 9, height: 1.35, fontWeight: FontWeight.w500, letterSpacing: 1.1),
          ),
          const SizedBox(height: 15),
          SizedBox(height: 205, width: double.infinity, child: CustomPaint(painter: _TrendChartPainter(trend))),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFA9B5F4), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(
                trend.averageLabel,
                style: const TextStyle(color: Color(0xFF77777A), fontSize: 10, height: 1, letterSpacing: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                trend.averageValue,
                style: const TextStyle(color: Color(0xFF202023), fontSize: 12, height: 1, fontWeight: FontWeight.w700, letterSpacing: 0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter(this.trend);

  final TestTrend trend;

  static const _lineColor = Color(0xFFA9B5F4);
  static const _labelColor = Color(0xFF77777A);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const top = 8.0;
    const right = 2.0;
    const bottom = 22.0;
    final chartRect = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final gridPaint = Paint()
      ..color = const Color(0xFFE3E4E8)
      ..strokeWidth = 1;

    final referenceTop = _valueToY(trend.maximumValue * 0.9375, chartRect);
    final referenceBottom = _valueToY(trend.maximumValue * 0.125, chartRect);
    canvas.drawRect(
      Rect.fromLTRB(chartRect.left, referenceTop, chartRect.right, referenceBottom),
      Paint()..color = _lineColor.withValues(alpha: 0.045),
    );

    for (var index = 0; index <= 4; index++) {
      final y = chartRect.top + chartRect.height * index / 4;
      _drawDashedLine(canvas, Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
      final value = trend.maximumValue - (trend.maximumValue - trend.minimumValue) * index / 4;
      _drawText(canvas, _formatAxisValue(value), Offset(0, y - 6), width: left - 8, textAlign: TextAlign.right);
    }

    _drawDashedLine(canvas, chartRect.topLeft, chartRect.bottomLeft, gridPaint);
    _drawDashedLine(canvas, chartRect.topRight, chartRect.bottomRight, gridPaint);

    if (trend.points.isEmpty) return;

    final points = <Offset>[];
    for (var index = 0; index < trend.points.length; index++) {
      final x = trend.points.length == 1 ? chartRect.center.dx : chartRect.left + chartRect.width * index / (trend.points.length - 1);
      points.add(Offset(x, _valueToY(trend.points[index].value, chartRect)));
      final labelWidth = index == 0 ? 55.0 : 55.0;
      final labelLeft = index == 0 ? x - 4 : x - labelWidth + 4;
      _drawText(canvas, trend.points[index].label, Offset(labelLeft, chartRect.bottom + 7), width: labelWidth, textAlign: index == 0 ? TextAlign.left : TextAlign.right);
    }

    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = _lineColor;
    for (final point in points) {
      canvas.drawCircle(point, 4.5, pointPaint);
    }
  }

  double _valueToY(double value, Rect chartRect) {
    final normalized = ((value - trend.minimumValue) / (trend.maximumValue - trend.minimumValue)).clamp(0.0, 1.0).toDouble();
    return chartRect.bottom - chartRect.height * normalized;
  }

  String _formatAxisValue(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  void _drawText(Canvas canvas, String text, Offset offset, {required double width, TextAlign textAlign = TextAlign.left}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: _labelColor, fontSize: 9, height: 1)),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 3.0;
    const dashSpace = 4.0;
    final distance = (end - start).distance;
    final direction = (end - start) / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final dashEnd = (drawn + dashWidth).clamp(0.0, distance).toDouble();
      canvas.drawLine(start + direction * drawn, start + direction * dashEnd, paint);
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => oldDelegate.trend != trend;
}
