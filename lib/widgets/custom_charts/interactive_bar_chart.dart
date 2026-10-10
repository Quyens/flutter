import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Biểu đồ cột tương tác theo dõi chi tiêu theo ngày vẽ bằng CustomPainter
class InteractiveBarChart extends StatefulWidget {
  final Map<DateTime, double> data;
  final double height;

  const InteractiveBarChart({
    super.key,
    required this.data,
    this.height = 240,
  });

  @override
  State<InteractiveBarChart> createState() => _InteractiveBarChartState();
}

class _InteractiveBarChartState extends State<InteractiveBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int? _selectedBarIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant InteractiveBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _animController.reset();
      _animController.forward();
      _selectedBarIndex = null;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, Size size) {
    if (widget.data.isEmpty) return;

    const leftPadding = 45.0;
    const rightPadding = 16.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final touchX = details.localPosition.dx;

    if (touchX < leftPadding || touchX > size.width - rightPadding) {
      setState(() => _selectedBarIndex = null);
      return;
    }

    final barCount = widget.data.length;
    final groupWidth = chartWidth / barCount;
    final index = ((touchX - leftPadding) / groupWidth).floor();

    if (index >= 0 && index < barCount) {
      setState(() {
        _selectedBarIndex = (_selectedBarIndex == index) ? null : index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'Chưa có dữ liệu chi tiêu',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, widget.height);
        return GestureDetector(
          onTapUp: (details) => _handleTap(details, size),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _BarChartPainter(
                  data: widget.data,
                  animationProgress: _animation.value,
                  selectedIndex: _selectedBarIndex,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<DateTime, double> data;
  final double animationProgress;
  final int? selectedIndex;

  _BarChartPainter({
    required this.data,
    required this.animationProgress,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 45.0;
    const rightPadding = 16.0;
    const topPadding = 35.0; // Khoảng trống cho tooltip khi chọn cột
    const bottomPadding = 30.0; // Khoảng trống cho nhãn ngày tháng

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final dates = data.keys.toList();
    final values = data.values.toList();
    final maxValue = values.fold(0.0, math.max);
    final effectiveMax = maxValue == 0 ? 100000.0 : (maxValue * 1.2); // Tăng 20% biên trên

    // 1. Vẽ các đường lưới trục Y và nhãn số tiền
    _drawGridAndYLabels(canvas, leftPadding, topPadding, chartWidth, chartHeight, effectiveMax);

    final barCount = dates.length;
    final groupWidth = chartWidth / barCount;
    final barWidth = groupWidth * 0.48;

    // 2. Vẽ từng cột chi tiêu
    for (int i = 0; i < barCount; i++) {
      final value = values[i];
      final date = dates[i];
      final isSelected = (selectedIndex == i);

      final centerX = leftPadding + (i * groupWidth) + (groupWidth / 2);
      final barHeight = (value / effectiveMax) * chartHeight * animationProgress;
      final barTop = topPadding + chartHeight - barHeight;
      final barLeft = centerX - (barWidth / 2);

      final barRect = Rect.fromLTWH(barLeft, barTop, barWidth, barHeight);

      // Gradient màu cho cột
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSelected
            ? [const Color(0xFFFF5252), const Color(0xFFFF7A00)]
            : [const Color(0xFF4A80F0), const Color(0xFF6C5CE7)],
      );

      final barPaint = Paint()
        ..shader = gradient.createShader(barRect)
        ..style = PaintingStyle.fill;

      // Vẽ bo góc đỉnh cột
      final rRect = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );
      canvas.drawRRect(rRect, barPaint);

      // Nếu đang được chọn -> vẽ viền highlight
      if (isSelected) {
        final borderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white;
        canvas.drawRRect(rRect, borderPaint);

        // Vẽ Tooltip nổi bật hiển thị chính xác số tiền trên đỉnh cột
        _drawTooltip(canvas, centerX, barTop, value);
      }

      // Vẽ nhãn ngày ở trục X
      final dayLabel = _formatDayLabel(date);
      final textPainter = TextPainter(
        text: TextSpan(
          text: dayLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey.shade600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(centerX - (textPainter.width / 2), topPadding + chartHeight + 8),
      );
    }
  }

  void _drawGridAndYLabels(
    Canvas canvas,
    double left,
    double top,
    double width,
    double height,
    double maxVal,
  ) {
    const gridCount = 3;
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.18)
      ..strokeWidth = 1.0;

    final currencyFormatter = NumberFormat.compactCurrency(
      locale: 'vi_VN',
      symbol: '₫',
    );

    for (int i = 0; i <= gridCount; i++) {
      final y = top + height - (i * (height / gridCount));
      final val = (i / gridCount) * maxVal;

      // Đường kẻ ngang
      canvas.drawLine(Offset(left, y), Offset(left + width, y), gridPaint);

      // Nhãn trục Y
      final yLabelPainter = TextPainter(
        text: TextSpan(
          text: currencyFormatter.format(val),
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      yLabelPainter.paint(
        canvas,
        Offset(left - yLabelPainter.width - 6, y - (yLabelPainter.height / 2)),
      );
    }
  }

  void _drawTooltip(Canvas canvas, double centerX, double topY, double value) {
    final fullFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final text = fullFormatter.format(value);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 8.0;
    const paddingV = 4.0;
    final tooltipWidth = textPainter.width + (paddingH * 2);
    final tooltipHeight = textPainter.height + (paddingV * 2);
    final tooltipY = topY - tooltipHeight - 8;
    final tooltipX = (centerX - (tooltipWidth / 2)).clamp(4.0, 500.0);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
      const Radius.circular(8),
    );

    // Vẽ bóng mờ tooltip
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(bgRect.shift(const Offset(0, 2)), shadowPaint);

    // Nền tooltip
    final bgPaint = Paint()..color = const Color(0xFF2C3E50);
    canvas.drawRRect(bgRect, bgPaint);

    // Chữ tooltip
    textPainter.paint(
      canvas,
      Offset(tooltipX + paddingH, tooltipY + paddingV),
    );
  }

  String _formatDayLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hôm nay';
    }
    // Hiển thị dạng Thứ hoặc ngày/tháng: vd "T2" hoặc "18/9"
    return DateFormat('E', 'vi_VN').format(date);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
           oldDelegate.selectedIndex != selectedIndex ||
           oldDelegate.data != data;
  }
}
