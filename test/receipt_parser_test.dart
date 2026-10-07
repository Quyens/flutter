import 'package:flutter_test/flutter_test.dart';
import 'package:expense_ocr_tracker/models/category_model.dart';
import 'package:expense_ocr_tracker/services/heuristic_receipt_parser.dart';

void main() {
  group('HeuristicReceiptParser Tests', () {
    test('Trích xuất hóa đơn Highlands Coffee tiếng Việt', () {
      const rawReceipt = '''
HIGHLANDS COFFEE
123 Lê Lợi, Phường Bến Nghé, Quận 1, TP.HCM
ĐT: 028.3822.4567 - MST: 0302829281
HÓA ĐƠN BÁN HÀNG
Số HĐ: HD-2023-89212
Ngày: 18/09/2023  14:35:10

1. Trà Sen Vàng (L)           65.000 đ
2. Freeze Trà Xanh (M)        59.000 đ
3. Bánh Mì Que Gà Cay        19.000 đ
--------------------------------------
Cộng tiền hàng:              143.000 đ
VAT (8%):                     11.440 đ
Tổng cộng thanh toán:        154.440 đ
Tiền khách đưa:              200.000 đ
Tiền thối lại:                45.560 đ
--------------------------------------
CẢM ƠN QUÝ KHÁCH & HẸN GẶP LẠI!
''';

      final result = HeuristicReceiptParser.parse(rawReceipt);

      expect(result.merchantName, contains('HIGHLANDS'));
      expect(result.totalAmount, equals(154440.0));
      expect(result.transactionDate?.day, equals(18));
      expect(result.transactionDate?.month, equals(9));
      expect(result.transactionDate?.year, equals(2023));
      expect(result.suggestedCategory, equals(ExpenseCategory.foodAndDining));
      expect(result.overallConfidence, greaterThan(0.7));
    });

    test('Trích xuất hóa đơn Siêu thị WinMart+ và danh mục Mua sắm', () {
      const rawReceipt = '''
SIÊU THỊ WINMART+
ĐC: 45 Nguyễn Huệ, Quận 1, TP.HCM
MST: 0104918404
PHIẾU THANH TOÁN
Ngày 22/09/2023 18:20
1. Sữa tươi tiệt trùng Vinamilk    36.000
2. Bánh mì sandwich ABC           24.000
3. Nước suối Lavie                10.000
--------------------------------------
Tổng thanh toán:                  70.000 đ
Khách trả:                       100.000 đ
Tiền thối:                        30.000 đ
''';

      final result = HeuristicReceiptParser.parse(rawReceipt);

      expect(result.merchantName, contains('WINMART'));
      expect(result.totalAmount, equals(70000.0));
      expect(result.transactionDate?.day, equals(22));
      expect(result.transactionDate?.month, equals(9));
      expect(result.suggestedCategory, equals(ExpenseCategory.shopping));
    });

    test('Trích xuất hóa đơn tiếng Anh (English Restaurant Bill)', () {
      const rawReceipt = '''
STARBUCKS COFFEE
Store #48291
Date: 2023-11-05 09:12
1 Caramel Macchiato         5.50
1 Croissant                 3.75
Subtotal:                   9.25
Tax (8%):                   0.74
Grand Total:                9.99 $
Payment: Visa ****1234
Thank you for visiting!
''';

      final result = HeuristicReceiptParser.parse(rawReceipt);

      expect(result.merchantName, contains('STARBUCKS'));
      expect(result.totalAmount, equals(9.99));
      expect(result.transactionDate?.year, equals(2023));
      expect(result.transactionDate?.month, equals(11));
      expect(result.transactionDate?.day, equals(5));
      expect(result.suggestedCategory, equals(ExpenseCategory.foodAndDining));
    });

    test('Trích xuất chuyến đi Grab và danh mục Di chuyển', () {
      const rawReceipt = '''
GRAB VIETNAM
Chuyến xe GrabCar
Mã chuyến: A-92812739
Ngày: 25/09/2023 08:30
Cước phí chuyến đi:       125.000 đ
Khuyến mãi:               -15.000 đ
Tổng tiền thanh toán:     110.000 đ
Thanh toán qua Ví Moca
''';

      final result = HeuristicReceiptParser.parse(rawReceipt);

      expect(result.merchantName, contains('GRAB'));
      expect(result.totalAmount, equals(110000.0));
      expect(result.suggestedCategory, equals(ExpenseCategory.transport));
    });
  });
}
