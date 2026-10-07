import 'package:intl/intl.dart';
import 'category_model.dart';

class Expense {
  final int? id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime dateTime;
  final String? note;
  final String? rawOcrText;
  final String? imagePath;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dateTime,
    this.note,
    this.rawOcrText,
    this.imagePath,
  });

  Expense copyWith({
    int? id,
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? dateTime,
    String? note,
    String? rawOcrText,
    String? imagePath,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'category': category.label,
      'date_time': dateTime.toIso8601String(),
      'note': note,
      'raw_ocr_text': rawOcrText,
      'image_path': imagePath,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title'] as String? ?? 'Khoản chi không tên',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: ExpenseCategory.fromString(map['category'] as String?),
      dateTime: map['date_time'] != null
          ? DateTime.tryParse(map['date_time'] as String) ?? DateTime.now()
          : DateTime.now(),
      note: map['note'] as String?,
      rawOcrText: map['raw_ocr_text'] as String?,
      imagePath: map['image_path'] as String?,
    );
  }

  String get formattedAmount {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return currencyFormatter.format(amount);
  }

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  String get formattedDateOnly {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}
