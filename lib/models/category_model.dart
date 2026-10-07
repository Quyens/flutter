import 'package:flutter/material.dart';

enum ExpenseCategory {
  foodAndDining('Ăn uống', Icons.restaurant_rounded, Color(0xFFFF6B6B)),
  shopping('Mua sắm', Icons.shopping_bag_rounded, Color(0xFF4ECDC4)),
  transport('Di chuyển', Icons.directions_car_rounded, Color(0xFF45B7D1)),
  bills('Hóa đơn', Icons.receipt_long_rounded, Color(0xFFFFA07A)),
  entertainment('Giải trí', Icons.movie_filter_rounded, Color(0xFF9B59B6)),
  health('Sức khỏe', Icons.local_hospital_rounded, Color(0xFF2ECC71)),
  other('Khác', Icons.category_rounded, Color(0xFF95A5A6));

  final String label;
  final IconData icon;
  final Color color;

  const ExpenseCategory(this.label, this.icon, this.color);

  static ExpenseCategory fromString(String? value) {
    if (value == null) return ExpenseCategory.other;
    return ExpenseCategory.values.firstWhere(
      (cat) => cat.label.toLowerCase() == value.toLowerCase() ||
               cat.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }
}
