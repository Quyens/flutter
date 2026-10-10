import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../models/category_model.dart';

/// Biểu đồ tròn tương tác vẽ hoàn toàn bằng CustomPainter
class InteractivePieChart extends StatefulWidget {
  final Map<ExpenseCategory, double> data;
  final double height;

  const InteractivePieChart({
    super.key,
    required this.data,
    this.height = 320,
  });

  @override
  State<InteractivePieChart> createState() => _InteractivePieChartState();
}

class _InteractivePieChartState extends State<InteractivePieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int? _selectedSliceIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant InteractivePieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _animController.reset();
      _animController.forward();
      _selectedSliceIndex = null;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, Size size) {
    if (widget.data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final touchPosition = details.localPosition;
    final dx = touchPosition.dx - center.dx;
    final dy = touchPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final outerRadius = math.min(size.width, size.height) / 2 * 0.85;
    final innerRadius = outerRadius * 0.58;

    // Kiểm tra xem điểm chạm có nằm trong vành bánh (Donut ring) không
    if (distance < innerRadius || distance > outerRadius * 1.15) {
      setState(() {
        _selectedSliceIndex = null;
      });
      return;
    }

    // Tính góc chạm tính từ trục 12 giờ (-pi/2)
    var touchAngle = math.atan2(dy, dx);
    touchAngle += (math.pi / 2); // Xoay để góc 0 bắt đầu từ hướng 12h
    if (touchAngle < 0) {
      touchAngle += 2 * math.pi;
    }

    final total = widget.data.values.fold(0.0, (sum, val) => sum + val);
    if (total == 0) return;

    final categories = widget.data.keys.toList();
    double currentAngle = 0.0;

    for (int i = 0; i < categories.length; i++) {
      final value = widget.data[categories[i]]!;
      final sweepAngle = (value / total) * 2 * math.pi;

      if (touchAngle >= currentAngle && touchAngle <= (currentAngle + sweepAngle)) {
        setState(() {
          _selectedSliceIndex = (_selectedSliceIndex == i) ? null : i;
        });
        return;
      }
      currentAngle += sweepAngle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.data.values.fold(0.0, (sum, val) => sum + val);
    final categories = widget.data.keys.toList();

    if (total == 0) {
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

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, widget.height);
              return GestureDetector(
                onTapUp: (details) => _handleTap(details, size),
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: size,
                      painter: _PieChartPainter(
                        data: widget.data,
                        categories: categories,
                        total: total,
                        animationProgress: _animation.value,
                        selectedIndex: _selectedSliceIndex,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Chú giải (Legend)
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(categories.length, (index) {
            final cat = categories[index];
            final amount = widget.data[cat]!;
            final percentage = (amount / total) * 100;
            final isSelected = _selectedSliceIndex == index;

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  _selectedSliceIndex = isSelected ? null : index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? cat.color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cat.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${cat.label} (${percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? cat.color : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// CustomPainter thực hiện vẽ các lát cắt hình tròn, hiệu ứng bóng mờ và tâm Donut
class _PieChartPainter extends CustomPainter {
  final Map<ExpenseCategory, double> data;
  final List<ExpenseCategory> categories;
  final double total;
  final double animationProgress;
  final int? selectedIndex;

  _PieChartPainter({
    required this.data,
    required this.categories,
    required this.total,
    required this.animationProgress,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 * 0.85;
    final innerRadius = outerRadius * 0.58;

    double startAngle = -math.pi / 2; // Bắt đầu ở đỉnh 12h
    final totalSweep = 2 * math.pi * animationProgress;

    // Vẽ bóng mờ nhẹ phía sau biểu đồ
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center + const Offset(0, 4), outerRadius, shadowPaint);

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final value = data[cat]!;
      final sweepAngle = (value / total) * totalSweep;
      final isSelected = (selectedIndex == i);

      // Nếu lát cắt được chọn -> tạo hiệu ứng nhô ra ngoài (exploded slice)
      Offset sliceCenterOffset = Offset.zero;
      double currentOuterRadius = outerRadius;

      if (isSelected) {
        final bisectorAngle = startAngle + (sweepAngle / 2);
        const explodeDistance = 8.0;
        sliceCenterOffset = Offset(
          math.cos(bisectorAngle) * explodeDistance,
          math.sin(bisectorAngle) * explodeDistance,
        );
        currentOuterRadius += 4.0;
      }

      final sliceCenter = center + sliceCenterOffset;
      final rect = Rect.fromCircle(center: sliceCenter, radius: currentOuterRadius);

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = cat.color;

      // Vẽ hình nan quạt
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Vẽ đường viền phân cách trắng tinh tế giữa các lát cắt
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      startAngle += sweepAngle;
    }

    // Vẽ lỗ Donut ở giữa
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, holePaint);

    // Vẽ nội dung tâm Donut (Thông tin tổng tiền hoặc mục đang chọn)
    _drawCenterContent(canvas, center, innerRadius);
  }

  void _drawCenterContent(Canvas canvas, Offset center, double innerRadius) {
    String title;
    String subtitle;
    Color textColor;

    final currencyFormatter = NumberFormat.compactCurrency(
      locale: 'vi_VN',
      symbol: '₫',
    );

    if (selectedIndex != null && selectedIndex! < categories.length) {
      final selectedCat = categories[selectedIndex!];
      final amount = data[selectedCat]!;
      final percent = (amount / total) * 100;

      title = selectedCat.label;
      subtitle = '${currencyFormatter.format(amount)}\n(${percent.toStringAsFixed(1)}%)';
      textColor = selectedCat.color;
    } else {
      title = 'Tổng chi';
      subtitle = currencyFormatter.format(total);
      textColor = Colors.black87;
    }

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: innerRadius * 1.6);

    final subPainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: textColor,
          height: 1.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: innerRadius * 1.6);

    final totalHeight = titlePainter.height + 4 + subPainter.height;
    final startY = center.dy - (totalHeight / 2);

    titlePainter.paint(
      canvas,
      Offset(center.dx - (titlePainter.width / 2), startY),
    );
    subPainter.paint(
      canvas,
      Offset(center.dx - (subPainter.width / 2), startY + titlePainter.height + 4),
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
           oldDelegate.selectedIndex != selectedIndex ||
           oldDelegate.data != data;
  }
}
