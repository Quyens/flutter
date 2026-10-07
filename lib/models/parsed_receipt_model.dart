import 'category_model.dart';

class ParsedReceipt {
  final String? merchantName;
  final double? totalAmount;
  final DateTime? transactionDate;
  final ExpenseCategory suggestedCategory;
  final double overallConfidence;
  final Map<String, double> fieldConfidences;
  final List<String> rawLines;
  final List<String> heuristicLogs;

  ParsedReceipt({
    this.merchantName,
    this.totalAmount,
    this.transactionDate,
    required this.suggestedCategory,
    required this.overallConfidence,
    required this.fieldConfidences,
    required this.rawLines,
    required this.heuristicLogs,
  });

  bool get isSuccessful => totalAmount != null && totalAmount! > 0;

  String get summary {
    return 'Cửa hàng: ${merchantName ?? "Không xác định"} | '
           'Số tiền: ${totalAmount != null ? totalAmount!.toStringAsFixed(0) : "N/A"} | '
           'Ngày: ${transactionDate != null ? transactionDate!.toIso8601String().substring(0, 10) : "N/A"} | '
           'Độ tin cậy: ${(overallConfidence * 100).toStringAsFixed(1)}%';
  }
}
