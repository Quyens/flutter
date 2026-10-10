import '../models/category_model.dart';
import '../models/parsed_receipt_model.dart';

/// Thuật toán Heuristic Regex Parser chuyên biệt cho hóa đơn (Receipt / Invoice)
/// Hỗ trợ cả hóa đơn tiếng Việt và tiếng Anh.
class HeuristicReceiptParser {
  // Danh sách từ khóa báo hiệu dòng Tổng tiền (Primary Keywords)
  static final List<String> _totalKeywords = [
    'tổng cộng', 'tong cong',
    'tổng thanh toán', 'tong thanh toan',
    'tổng tiền', 'tong tien',
    'thanh toán', 'thanh toan',
    'tiền thanh toán', 'tien thanh toan',
    'phải trả', 'phai tra',
    'cần trả', 'can tra',
    'cộng tiền', 'cong tien',
    'cộng',
    'grand total', 'net total', 'amount due', 'total amount', 'total',
  ];

  // Danh sách từ khóa nên loại trừ khi tìm Tổng tiền (tránh lấy nhầm Tiền khách đưa, Tiền thối, Thẻ)
  static final List<String> _avoidTotalKeywords = [
    'tiền khách đưa', 'tien khach dua',
    'khách đưa', 'khach dua',
    'khách trả', 'khach tra',
    'tiền thừa', 'tien thua',
    'tiền thối', 'tien thoi',
    'thối lại', 'thoi lai',
    'change', 'cash given', 'customer cash',
    'điểm tích', 'tích lũy', 'mst', 'mã số thuế', 'stk', 'tài khoản',
    'visa', 'mastercard', 'payment', 'card', 'thẻ', '****', 'subtotal',
  ];

  // Danh sách từ khóa nhận diện thương hiệu phổ biến
  static final List<String> _knownBrands = [
    'highlands coffee', 'highlands', 'phúc long', 'phuclong', 'starbucks',
    'the coffee house', 'trung nguyên', 'katinat', 'cheese coffee', 'chay',
    'kfc', 'lotteria', 'jollibee', 'mcdonald', 'pizza hut', 'domino', 'haidilao',
    'winmart', 'winmart+', 'circle k', 'gs25', 'familymart', '7-eleven', 'ministop',
    'co.opmart', 'coopmart', 'bách hóa xanh', 'bach hoa xanh', 'big c', 'go!', 'lotte mart',
    'long châu', 'nhà thuốc an khang', 'pharmacity',
    'grab', 'be', 'gojek', 'xanh sm', 'petrolimex',
  ];

  // Danh sách từ khóa nhận diện loại hình kinh doanh (Merchant Prefix)
  static final List<String> _merchantPrefixes = [
    'nhà hàng', 'nha hang', 'quán', 'quan', 'tiệm', 'tiem',
    'cà phê', 'ca phe', 'coffee', 'cafe', 'trà sữa', 'tra sua',
    'cửa hàng', 'cua hang', 'siêu thị', 'sieu thi', 'store', 'shop', 'mart',
    'công ty', 'cong ty', 'tnhh', 'cp', 'doanh nghiệp',
    'bakery', 'restaurant', 'bistro', 'boutique', 'pharmacy',
  ];

  // Tiêu đề hóa đơn thông thường cần bỏ qua khi tìm Merchant Name
  static final List<String> _headerNoiseKeywords = [
    'hóa đơn', 'hoa don', 'phiếu thanh toán', 'phieu thanh toan',
    'phiếu tính tiền', 'phieu tinh tien', 'biên lai', 'bien lai',
    'phiếu thu', 'phieu thu', 'order', 'receipt', 'bill', 'tax invoice',
    'cộng hòa xã hội chủ nghĩa việt nam', 'độc lập - tự do - hạnh phúc',
    'chào mừng quý khách', 'thank you', 'cảm ơn quý khách',
  ];

  /// Hàm phân tích chính: Nhận vào chuỗi thô từ OCR và trả về đối tượng [ParsedReceipt]
  static ParsedReceipt parse(String rawOcrText) {
    final List<String> logs = [];
    final List<String> lines = rawOcrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    logs.add('Bắt đầu phân tích Heuristic Regex: ${lines.length} dòng văn bản.');

    // 1. Trích xuất tên người bán (Merchant Name)
    final merchantResult = _extractMerchantName(lines, logs);

    // 2. Trích xuất ngày giao dịch (Transaction Date)
    final dateResult = _extractTransactionDate(lines, logs);

    // 3. Trích xuất tổng tiền (Total Amount)
    final amountResult = _extractTotalAmount(lines, logs);

    // 4. Dự đoán danh mục chi tiêu (Category Suggestion)
    final category = _suggestCategory(
      merchantResult.value ?? '',
      rawOcrText,
      logs,
    );

    // Tính điểm tin cậy tổng thể (Overall Confidence)
    final fieldConfidences = {
      'merchant': merchantResult.confidence,
      'date': dateResult.confidence,
      'amount': amountResult.confidence,
    };

    final overallConfidence = (merchantResult.confidence * 0.25) +
        (dateResult.confidence * 0.25) +
        (amountResult.confidence * 0.50);

    logs.add('Hoàn tất phân tích. Độ tin cậy tổng thể: ${(overallConfidence * 100).toStringAsFixed(1)}%');

    return ParsedReceipt(
      merchantName: merchantResult.value,
      totalAmount: amountResult.value,
      transactionDate: dateResult.value,
      suggestedCategory: category,
      overallConfidence: overallConfidence,
      fieldConfidences: fieldConfidences,
      rawLines: lines,
      heuristicLogs: logs,
    );
  }

  /// Trích xuất Merchant Name theo luật Heuristic
  static _ParseField<String> _extractMerchantName(List<String> lines, List<String> logs) {
    if (lines.isEmpty) {
      return _ParseField<String>(null, 0.0);
    }

    String? bestCandidate;
    double highestScore = -1.0;

    // Xem xét 6 dòng đầu tiên của hóa đơn
    final int searchLimit = lines.length < 6 ? lines.length : 6;

    for (int i = 0; i < searchLimit; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();
      double score = 0.0;

      // Bỏ qua nếu dòng là tiêu đề hóa đơn thuần túy (e.g. "HÓA ĐƠN BÁN HÀNG")
      bool isNoise = false;
      for (final noise in _headerNoiseKeywords) {
        if (lineLower == noise || lineLower.startsWith('$noise ') || lineLower.contains('cộng hòa')) {
          isNoise = true;
          break;
        }
      }
      if (isNoise) continue;

      // Bỏ qua nếu dòng chứa địa chỉ hoặc số điện thoại hoặc MST
      if (lineLower.contains('đ/c') || lineLower.contains('địa chỉ') ||
          lineLower.contains('hotline') || lineLower.contains('mst:') ||
          lineLower.contains('tel:') || lineLower.contains('phone:')) {
        continue;
      }

      // Điểm ưu tiên vị trí: dòng càng cao điểm càng lớn
      score += (searchLimit - i) * 6.0;

      // Kiểm tra thương hiệu đã biết
      for (final brand in _knownBrands) {
        if (lineLower.contains(brand)) {
          score += 60.0;
          logs.add('Phát hiện thương hiệu quen thuộc "$brand" ở dòng $i: "$line"');
          break;
        }
      }

      // Kiểm tra tiền tố kinh doanh
      for (final prefix in _merchantPrefixes) {
        if (lineLower.contains(prefix)) {
          score += 35.0;
          logs.add('Phát hiện tiền tố kinh doanh "$prefix" ở dòng $i: "$line"');
          break;
        }
      }

      // Nếu dòng viết HOA toàn bộ và dài từ 4 đến 35 ký tự
      if (line == line.toUpperCase() && line.length >= 4 && line.length <= 35) {
        score += 15.0;
      }

      // Phạt điểm nếu dòng chứa nhiều chữ số (số lượng, giá tiền, ngày)
      final digitCount = line.replaceAll(RegExp(r'\D'), '').length;
      if (digitCount > 4) {
        score -= 25.0;
      }

      if (score > highestScore && score > 15.0) {
        highestScore = score;
        bestCandidate = line;
      }
    }

    // Fallback: nếu chưa tìm thấy, lấy dòng đầu tiên không phải noise
    if (bestCandidate == null) {
      for (final line in lines.take(3)) {
        if (!_headerNoiseKeywords.any((n) => line.toLowerCase().contains(n)) &&
            line.length > 3) {
          bestCandidate = line;
          highestScore = 20.0;
          break;
        }
      }
    }

    final double confidence = (highestScore / 100.0).clamp(0.2, 0.95);
    logs.add('Merchant được chọn: "${bestCandidate ?? "Không tìm thấy"}" (Score: $highestScore, Conf: ${(confidence * 100).toStringAsFixed(1)}%)');

    return _ParseField<String>(bestCandidate, bestCandidate != null ? confidence : 0.0);
  }

  /// Trích xuất Ngày giao dịch bằng chuỗi Regex ngày tháng
  static _ParseField<DateTime> _extractTransactionDate(List<String> lines, List<String> logs) {
    DateTime? detectedDate;
    double confidence = 0.0;

    // Pattern 1: dd/MM/yyyy hoặc dd-MM-yyyy hoặc dd.MM.yyyy
    final regDDMMYYYY = RegExp(
      r'(?:ngày|ngay|date)?\s*[:\s]?\s*(\b[0-3]?[0-9])[\/\-\.]([0-1]?[0-9])[\/\-\.](20[1-3][0-9]|[1-3][0-9]\b)',
      caseSensitive: false,
    );

    // Pattern 2: yyyy/MM/dd hoặc yyyy-MM-dd
    final regYYYYMMDD = RegExp(
      r'(\b20[1-3][0-9])[\/\-\.]([0-1]?[0-9])[\/\-\.]([0-3]?[0-9]\b)',
    );

    // Pattern 3: Văn bản tiếng Việt: Ngày dd tháng MM năm yyyy
    final regVietText = RegExp(
      r'(?:ngày|ngay)\s*(\d{1,2})\s*(?:tháng|thg|th)\s*(\d{1,2})(?:\s*(?:năm|nam)\s*(20\d{2}))?',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Thử Pattern 3 trước (Văn bản tiếng Việt chuẩn)
      final matchViet = regVietText.firstMatch(line);
      if (matchViet != null) {
        final day = int.tryParse(matchViet.group(1) ?? '');
        final month = int.tryParse(matchViet.group(2) ?? '');
        final year = int.tryParse(matchViet.group(3) ?? '') ?? DateTime.now().year;
        if (day != null && month != null && _isValidDate(day, month, year)) {
          detectedDate = DateTime(year, month, day);
          confidence = 0.95;
          logs.add('Tìm thấy ngày (Tiếng Việt rõ ràng) ở dòng $i: $day/$month/$year');
          break;
        }
      }

      // Thử Pattern 1 (dd/MM/yyyy)
      final match1 = regDDMMYYYY.firstMatch(line);
      if (match1 != null) {
        final day = int.tryParse(match1.group(1) ?? '');
        final month = int.tryParse(match1.group(2) ?? '');
        var year = int.tryParse(match1.group(3) ?? '');
        if (year != null && year < 100) year += 2000;

        if (day != null && month != null && year != null && _isValidDate(day, month, year)) {
          detectedDate = DateTime(year, month, day);
          confidence = line.toLowerCase().contains('ngày') || line.toLowerCase().contains('date') ? 0.90 : 0.80;
          logs.add('Tìm thấy ngày (dd/MM/yyyy) ở dòng $i: $day/$month/$year');
          break;
        }
      }

      // Thử Pattern 2 (yyyy-MM-dd)
      final match2 = regYYYYMMDD.firstMatch(line);
      if (match2 != null) {
        final year = int.tryParse(match2.group(1) ?? '');
        final month = int.tryParse(match2.group(2) ?? '');
        final day = int.tryParse(match2.group(3) ?? '');

        if (day != null && month != null && year != null && _isValidDate(day, month, year)) {
          detectedDate = DateTime(year, month, day);
          confidence = 0.85;
          logs.add('Tìm thấy ngày (yyyy-MM-dd) ở dòng $i: $year-$month-$day');
          break;
        }
      }
    }

    // Nếu không tìm thấy, fallback ngày hiện tại với độ tin cậy thấp
    if (detectedDate == null) {
      detectedDate = DateTime.now();
      confidence = 0.3;
      logs.add('Không tìm thấy ngày trên hóa đơn. Sử dụng ngày hiện tại.');
    }

    return _ParseField<DateTime>(detectedDate, confidence);
  }

  /// Trích xuất Tổng tiền theo thuật toán Heuristic nhiều cấp
  static _ParseField<double> _extractTotalAmount(List<String> lines, List<String> logs) {
    double? detectedAmount;
    double highestScore = -1.0;

    // Pattern nhận diện số tiền (hỗ trợ cả định dạng VNĐ 150.000, 70.000 và tiền USD 9.99, 15.50)
    final regAmount = RegExp(
      r'(?:(?:\$|₫|đ|vnd|vnđ)\s*)?([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?|[0-9]+[.,][0-9]{1,2}|[0-9]{4,9})(?:\s*(?:₫|đ|vnd|vnđ|\$))?',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      // Bỏ qua dòng tiêu đề hóa đơn chung (phiếu thanh toán, hóa đơn) để tránh nhầm thành dòng tổng tiền
      if (_headerNoiseKeywords.any((noise) => lineLower.contains(noise))) {
        continue;
      }

      // Kiểm tra xem dòng có từ khóa tiêu cực (tiền khách đưa, thối lại, thẻ) không
      bool hasAvoidKeyword = false;
      for (final avoid in _avoidTotalKeywords) {
        if (lineLower.contains(avoid)) {
          hasAvoidKeyword = true;
          break;
        }
      }

      // Kiểm tra từ khóa Tổng tiền
      int keywordWeight = 0;
      for (final kw in _totalKeywords) {
        if (lineLower.contains(kw)) {
          if (kw == 'tổng cộng' || kw == 'tong cong' ||
              kw == 'tổng thanh toán' || kw == 'tong thanh toan' ||
              kw == 'tổng tiền' || kw == 'tong tien' ||
              kw == 'grand total' || kw == 'net total' || kw == 'amount due') {
            keywordWeight = 60;
          } else {
            keywordWeight = 35;
          }
          break;
        }
      }

      // Tìm số tiền xuất hiện trên chính dòng này
      final matches = regAmount.allMatches(line);
      for (final match in matches) {
        final rawNumberStr = match.group(1);
        final amountValue = _cleanAndParseNumber(rawNumberStr);

        if (amountValue != null && amountValue > 0) {
          // Bỏ qua nếu là số quá nhỏ (< 100) khi không có ký hiệu $ và không có từ khóa tổng tiền
          final isSmallNumber = amountValue < 100 && !lineLower.contains(r'$') && keywordWeight == 0;
          if (isSmallNumber) continue;

          // Bỏ qua nếu dòng là ngày tháng và số này trùng với năm (2018 - 2035)
          if ((lineLower.contains('ngày') || lineLower.contains('date')) &&
              amountValue >= 2018 && amountValue <= 2035) {
            continue;
          }

          double score = 0.0;
          score += keywordWeight;

          // Phạt nặng nếu cùng dòng có từ khóa tiền thối / tiền khách đưa / thẻ visa
          if (hasAvoidKeyword) {
            score -= 60.0;
          }

          // Điểm cộng nếu có ký hiệu tiền tệ (đ, vnđ, $)
          if (lineLower.contains('đ') || lineLower.contains('vnd') || lineLower.contains('vnđ') || lineLower.contains(r'$')) {
            score += 15.0;
          }

          // Vị trí nằm ở nửa sau của hóa đơn (hóa đơn thường tổng tiền ở cuối)
          if (i > (lines.length / 2)) {
            score += 15.0;
          }

          logs.add('Phát hiện ứng viên tiền tệ: $amountValue trên dòng $i ("$line") với Score: $score');

          if (score > highestScore) {
            highestScore = score;
            detectedAmount = amountValue;
          }
        }
      }

      // Nếu dòng chứa từ khóa Tổng tiền nhưng số lại nằm ở dòng ngay sau (Dòng i+1)
      if (keywordWeight > 0 && matches.isEmpty && (i + 1) < lines.length) {
        final nextLine = lines[i + 1];
        final nextLineLower = nextLine.toLowerCase();
        if (!_avoidTotalKeywords.any((avoid) => nextLineLower.contains(avoid)) &&
            !nextLineLower.contains('ngày') && !nextLineLower.contains('date')) {
          final nextMatches = regAmount.allMatches(nextLine);
          for (final match in nextMatches) {
            final rawNumberStr = match.group(1);
            final amountValue = _cleanAndParseNumber(rawNumberStr);
            if (amountValue != null && amountValue > 0) {
              if (amountValue >= 2018 && amountValue <= 2035 &&
                  (nextLineLower.contains('ngày') || nextLineLower.contains('date'))) {
                continue;
              }
              double score = keywordWeight + 20.0; // Điểm liền kề
              logs.add('Phát hiện tiền ở dòng kế tiếp ($amountValue) của từ khóa ở dòng $i. Score: $score');
              if (score > highestScore) {
                highestScore = score;
                detectedAmount = amountValue;
              }
            }
          }
        }
      }
    }

    // Fallback Heuristic: Nếu không khớp từ khóa rõ ràng, tìm số lớn nhất hợp lý ở nửa cuối hóa đơn
    if (detectedAmount == null || highestScore < 20.0) {
      double maxFound = 0.0;
      final int startFrom = (lines.length * 0.4).toInt();
      for (int i = startFrom; i < lines.length; i++) {
        final lineLower = lines[i].toLowerCase();
        if (_avoidTotalKeywords.any((avoid) => lineLower.contains(avoid))) continue;

        for (final match in regAmount.allMatches(lines[i])) {
          final val = _cleanAndParseNumber(match.group(1));
          if (val != null && val > maxFound && val < 1000000000) { // < 1 tỷ VNĐ
            maxFound = val;
          }
        }
      }

      if (maxFound > 0.0) {
        detectedAmount = maxFound;
        highestScore = 35.0;
        logs.add('Sử dụng Fallback Max Amount: $detectedAmount (Score: $highestScore)');
      }
    }

    final double confidence = (highestScore / 100.0).clamp(0.1, 0.98);
    logs.add('Tổng tiền được chọn: ${detectedAmount != null ? detectedAmount.toStringAsFixed(0) : "Không tìm thấy"} (Conf: ${(confidence * 100).toStringAsFixed(1)}%)');

    return _ParseField<double>(detectedAmount, detectedAmount != null ? confidence : 0.0);
  }

  /// Dự đoán danh mục chi tiêu tự động dựa trên tên quán và nội dung hóa đơn
  static ExpenseCategory _suggestCategory(String merchant, String fullText, List<String> logs) {
    final merchantLower = merchant.toLowerCase();
    final combined = '$merchant $fullText'.toLowerCase();

    // Ưu tiên 1: Tên thương hiệu/người bán (Merchant Name) có trọng số cao nhất
    if (_containsAny(merchantLower, [
      'siêu thị', 'mart', 'winmart', 'circle k', 'gs25', 'familymart', '7-eleven',
      'co.opmart', 'coopmart', 'bách hóa xanh', 'bach hoa xanh', 'big c', 'lotte mart',
      'shop', 'store'
    ])) {
      logs.add('Dự đoán danh mục (theo Merchant): Mua sắm');
      return ExpenseCategory.shopping;
    }

    if (_containsAny(merchantLower, [
      'cà phê', 'cafe', 'coffee', 'trà sữa', 'tra sua', 'highlands', 'phúc long',
      'starbucks', 'katinat', 'cheese coffee', 'quán', 'nhà hàng', 'restaurant',
      'kfc', 'lotteria', 'jollibee', 'pizza', 'bbq', 'lẩu', 'nướng', 'haidilao', 'bistro'
    ])) {
      logs.add('Dự đoán danh mục (theo Merchant): Ăn uống');
      return ExpenseCategory.foodAndDining;
    }

    if (_containsAny(merchantLower, [
      'grab', 'be', 'gojek', 'xanh sm', 'taxi', 'petrolimex'
    ])) {
      logs.add('Dự đoán danh mục (theo Merchant): Di chuyển');
      return ExpenseCategory.transport;
    }

    if (_containsAny(merchantLower, [
      'nhà thuốc', 'pharmacity', 'long châu', 'an khang', 'bệnh viện', 'phòng khám'
    ])) {
      logs.add('Dự đoán danh mục (theo Merchant): Sức khỏe');
      return ExpenseCategory.health;
    }

    // Ưu tiên 2: Nội dung chi tiết các dòng trong hóa đơn (Item list)
    // 1. Mua sắm (Shopping)
    if (_containsAny(combined, [
      'siêu thị', 'mart', 'winmart', 'circle k', 'gs25', 'familymart', '7-eleven',
      'co.opmart', 'bách hóa xanh', 'big c', 'lotte mart', 'quần áo', 'thời trang',
      'zara', 'uniqlo', 'shopee', 'tiki', 'lazada'
    ])) {
      logs.add('Dự đoán danh mục: Mua sắm');
      return ExpenseCategory.shopping;
    }

    // 2. Ăn uống (Food & Dining)
    if (_containsAny(combined, [
      'cà phê', 'cafe', 'coffee', 'trà sữa', 'tra sua', 'highlands', 'phúc long',
      'starbucks', 'katinat', 'cheese coffee', 'quán cơm', 'phở', 'bún', 'bánh mì',
      'nhà hàng', 'restaurant', 'kfc', 'lotteria', 'jollibee', 'pizza', 'bbq',
      'lẩu', 'nướng', 'haidilao', 'bistro', 'food', 'ăn', 'uống'
    ])) {
      logs.add('Dự đoán danh mục: Ăn uống');
      return ExpenseCategory.foodAndDining;
    }

    // 3. Di chuyển (Transport)
    if (_containsAny(combined, [
      'grab', 'be ', 'gojek', 'xanh sm', 'taxi', 'petrolimex', 'xăng dầu',
      'vé xe', 'bến xe', 'vé tàu', 'vé máy bay', 'gửi xe', 'parking'
    ])) {
      logs.add('Dự đoán danh mục: Di chuyển');
      return ExpenseCategory.transport;
    }

    // 4. Sức khỏe (Healthcare)
    if (_containsAny(combined, [
      'nhà thuốc', 'pharmacity', 'long châu', 'an khang', 'bệnh viện', 'phòng khám',
      'thuốc', 'khám bệnh', 'bác sĩ'
    ])) {
      logs.add('Dự đoán danh mục: Sức khỏe');
      return ExpenseCategory.health;
    }

    // 5. Hóa đơn (Bills)
    if (_containsAny(combined, [
      'điện lực', 'evn', 'cấp nước', 'tiền nước', 'internet', 'viettel',
      'vinaphone', 'mobifone', 'fpt telecom', 'hóa đơn tiền điện'
    ])) {
      logs.add('Dự đoán danh mục: Hóa đơn');
      return ExpenseCategory.bills;
    }

    // 6. Giải trí (Entertainment)
    if (_containsAny(combined, [
      'cgv', 'lotte cinema', 'galaxy', 'bhd', 'rạp phim', 'karaoke',
      'game', 'khu vui chơi', 'vé tham quan', 'concert'
    ])) {
      logs.add('Dự đoán danh mục: Giải trí');
      return ExpenseCategory.entertainment;
    }

    logs.add('Dự đoán danh mục: Khác (Mặc định)');
    return ExpenseCategory.other;
  }

  // Tiện ích làm sạch chuỗi số sang kiểu double
  static double? _cleanAndParseNumber(String? str) {
    if (str == null) return null;

    // Loại bỏ khoảng trắng và ký hiệu tiền tệ
    String cleaned = str.replaceAll(RegExp(r'[\s₫đvndvnđ\$]', caseSensitive: false), '');

    // Nếu định dạng kiểu Việt Nam: 150.000 hoặc 150,000 (dấu phân cách hàng nghìn)
    // Nếu có cả . và , ví dụ 1,250.50 (chuẩn Anh/Mỹ)
    if (cleaned.contains('.') && cleaned.contains(',')) {
      // Ví dụ: 1.250,50 (VN) hoặc 1,250.50 (US)
      final lastDot = cleaned.lastIndexOf('.');
      final lastComma = cleaned.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Chuẩn Việt Nam: 1.250,50 -> loại bỏ . và thay , bằng .
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Chuẩn US: 1,250.50 -> loại bỏ ,
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains('.')) {
      // Có dấu chấm. Kiểm tra xem là phân cách hàng nghìn (150.000) hay số thập phân (15.50)
      final parts = cleaned.split('.');
      if (parts.length > 1 && parts.last.length == 3) {
        // 150.000 -> dấu chấm hàng nghìn
        cleaned = cleaned.replaceAll('.', '');
      } else if (parts.length > 2) {
        // 1.500.000 -> hàng nghìn
        cleaned = cleaned.replaceAll('.', '');
      }
    } else if (cleaned.contains(',')) {
      // Có dấu phẩy. Tương tự như trên
      final parts = cleaned.split(',');
      if (parts.length > 1 && parts.last.length == 3) {
        // 150,000 -> hàng nghìn
        cleaned = cleaned.replaceAll(',', '');
      } else if (parts.length > 2) {
        cleaned = cleaned.replaceAll(',', '');
      }
    }

    return double.tryParse(cleaned);
  }

  static bool _isValidDate(int day, int month, int year) {
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    if (year < 2018 || year > 2035) return false;
    return true;
  }

  static bool _containsAny(String text, List<String> terms) {
    return terms.any((term) => text.contains(term));
  }
}

class _ParseField<T> {
  final T? value;
  final double confidence;
  _ParseField(this.value, this.confidence);
}
