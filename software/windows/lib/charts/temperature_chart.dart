import 'dart:math' as math;

import 'package:flutter/material.dart';

class TemperaturePoint {
  const TemperaturePoint(this.time, this.inside, this.outside);

  final DateTime time;
  final double? inside;
  final double? outside;
}

/// نمودار سبک داخلی؛ تا انتخاب بستهٔ نمودار، به وابستگی خارجی احتیاج ندارد.
class TemperatureChart extends StatelessWidget {
  const TemperatureChart({
    required this.points,
    this.axisLabel = 'دما (°C)',
    super.key,
  });
  final String axisLabel;

  final List<TemperaturePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const Center(
        child: Text('برای رسم نمودار، دست‌کم دو نمونه لازم است.'),
      );
    }
    return CustomPaint(
      painter: _TemperaturePainter(points, axisLabel),
      child: const SizedBox.expand(),
    );
  }
}

class _TemperaturePainter extends CustomPainter {
  _TemperaturePainter(this.points, this.axisLabel);
  final String axisLabel;
  final List<TemperaturePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    // برای جا دادن عنوان محور عمودی، اعداد دما و برچسب‌های زمان،
    // فضای نمودار را از لبه‌ها جدا می‌کنیم تا متن‌ها روی خطوط نیفتند.
    final chart = Rect.fromLTWH(58, 16, size.width - 72, size.height - 62);
    if (chart.width <= 0 || chart.height <= 0) return;

    final allValues = points
        .expand((point) => [point.inside, point.outside])
        .whereType<double>()
        .toList();
    if (allValues.isEmpty) return;
    final minValue = allValues.reduce((a, b) => a < b ? a : b) - 1;
    final maxValue = allValues.reduce((a, b) => a > b ? a : b) + 1;
    final span = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;
    final firstTime = points.first.time.millisecondsSinceEpoch;
    final timeSpan = points.last.time.millisecondsSinceEpoch - firstTime;

    final gridPaint = Paint()
      ..color = const Color(0x334E6B7C)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = chart.top + chart.height * row / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);

      // هر خط افقی یک مقدار دما دارد تا مقیاس عمودی قابل خواندن باشد.
      final value = maxValue - span * row / 3;
      _drawText(
        canvas,
        value.toStringAsFixed(1),
        Offset(chart.left - 8, y),
        color: const Color(0xFFB8C8D2),
        fontSize: 11,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        anchor: _TextAnchor.centerRight,
      );
    }

    // سه نشانهٔ زمانی (ابتدا، میانه و انتها) از شلوغ شدن محور افقی جلوگیری می‌کنند.
    final timeSamples = List.generate(
      3,
      (index) => DateTime.fromMillisecondsSinceEpoch(
        firstTime + timeSpan * index ~/ 2,
      ),
    );
    for (var index = 0; index < timeSamples.length; index++) {
      final x = chart.left + chart.width * index / 2;
      final label = _formatTimeLabel(
        timeSamples[index],
        points.first.time,
        points.last.time,
      );
      _drawText(
        canvas,
        label,
        Offset(x, chart.bottom + 8),
        color: const Color(0xFFB8C8D2),
        fontSize: 11,
        textAlign: index == 0
            ? TextAlign.left
            : index == 2
            ? TextAlign.right
            : TextAlign.center,
        textDirection: TextDirection.ltr,
        anchor: index == 0
            ? _TextAnchor.topLeft
            : index == 2
            ? _TextAnchor.topRight
            : _TextAnchor.topCenter,
      );
    }

    // عنوان محور افقی و عمودی، واحد دما را نیز به‌صورت روشن مشخص می‌کند.
    _drawText(
      canvas,
      'زمان',
      Offset(chart.center.dx, size.height - 2),
      color: const Color(0xFFD4E1E8),
      fontSize: 12,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      anchor: _TextAnchor.bottomCenter,
    );
    canvas.save();
    canvas.translate(13, chart.center.dy);
    canvas.rotate(-math.pi / 2);
    _drawText(
      canvas,
      axisLabel,
      Offset.zero,
      color: const Color(0xFFD4E1E8),
      fontSize: 12,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      anchor: _TextAnchor.center,
    );
    canvas.restore();

    _drawLine(
      canvas,
      chart,
      minValue,
      span,
      firstTime,
      timeSpan,
      (point) => point.inside,
      const Color(0xFF60E0CD),
    );
    _drawLine(
      canvas,
      chart,
      minValue,
      span,
      firstTime,
      timeSpan,
      (point) => point.outside,
      const Color(0xFFFFC97B),
    );
  }

  String _formatTimeLabel(DateTime time, DateTime first, DateTime last) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    if (last.difference(first).inHours < 24) {
      return '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
    }
    return '${twoDigits(time.month)}/${twoDigits(time.day)}';
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset anchorPoint, {
    required Color color,
    required double fontSize,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required _TextAnchor anchor,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: 1,
    )..layout();

    final offset = switch (anchor) {
      _TextAnchor.centerRight => Offset(
        anchorPoint.dx - painter.width,
        anchorPoint.dy - painter.height / 2,
      ),
      _TextAnchor.topLeft => anchorPoint,
      _TextAnchor.topCenter => Offset(
        anchorPoint.dx - painter.width / 2,
        anchorPoint.dy,
      ),
      _TextAnchor.topRight => Offset(
        anchorPoint.dx - painter.width,
        anchorPoint.dy,
      ),
      _TextAnchor.bottomCenter => Offset(
        anchorPoint.dx - painter.width / 2,
        anchorPoint.dy - painter.height,
      ),
      _TextAnchor.center => Offset(
        anchorPoint.dx - painter.width / 2,
        anchorPoint.dy - painter.height / 2,
      ),
    };
    painter.paint(canvas, offset);
  }

  void _drawLine(
    Canvas canvas,
    Rect chart,
    double minValue,
    double span,
    int firstTime,
    int timeSpan,
    double? Function(TemperaturePoint) select,
    Color color,
  ) {
    final valid = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final value = select(points[index]);
      if (value == null) continue;
      valid.add(
        Offset(
          chart.left +
              chart.width *
                  (timeSpan == 0
                      ? index / (points.length - 1)
                      : (points[index].time.millisecondsSinceEpoch -
                                firstTime) /
                            timeSpan),
          chart.bottom - chart.height * (value - minValue) / span,
        ),
      );
    }
    if (valid.length < 2) return;
    final path = Path()..moveTo(valid.first.dx, valid.first.dy);
    for (final point in valid.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TemperaturePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.axisLabel != axisLabel;
}

enum _TextAnchor {
  centerRight,
  topLeft,
  topCenter,
  topRight,
  bottomCenter,
  center,
}
