import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../models/parsed_receipt_model.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../services/heuristic_receipt_parser.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _isProcessing = false;
  ParsedReceipt? _parsedReceipt;

  // Controllers cho form xác nhận sau khi quét
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  ExpenseCategory _selectedCategory = ExpenseCategory.foodAndDining;

  @override
  void dispose() {
    _ocrService.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _isProcessing = true;
        _parsedReceipt = null;
      });

      // Thực hiện quét OCR và phân tích Heuristic Regex
      final result = await _ocrService.processReceiptImage(pickedFile.path);
      _applyParsedResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xử lý ảnh: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _testWithSampleReceipt(String sampleName, String rawText) {
    setState(() {
      _isProcessing = true;
      _imageFile = null;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      final result = HeuristicReceiptParser.parse(rawText);
      _applyParsedResult(result);
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  void _applyParsedResult(ParsedReceipt result) {
    setState(() {
      _parsedReceipt = result;
      _titleController.text = result.merchantName ?? 'Khoản chi từ hóa đơn';
      _amountController.text = result.totalAmount != null
          ? result.totalAmount!.toStringAsFixed(0)
          : '';
      _selectedDate = result.transactionDate ?? DateTime.now();
      _selectedCategory = result.suggestedCategory;
      _noteController.text = 'Quét OCR (Độ tin cậy: ${(result.overallConfidence * 100).toStringAsFixed(0)}%)';
    });
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ!')),
      );
      return;
    }

    final expense = Expense(
      title: _titleController.text.trim().isEmpty ? 'Hóa đơn không tên' : _titleController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      dateTime: _selectedDate,
      note: _noteController.text.trim(),
      rawOcrText: _parsedReceipt?.rawLines.join('\n'),
      imagePath: _imageFile?.path,
    );

    await DatabaseService.instance.insertExpense(expense);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu khoản chi tiêu thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét Hóa Đơn OCR'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Chọn hóa đơn mẫu để thử nghiệm',
            icon: const Icon(Icons.science_outlined),
            onSelected: (val) {
              if (val == 'highlands') {
                _testWithSampleReceipt('Highlands Coffee', _sampleHighlands);
              } else if (val == 'winmart') {
                _testWithSampleReceipt('WinMart+', _sampleWinMart);
              } else if (val == 'grab') {
                _testWithSampleReceipt('Grab Transport', _sampleGrab);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'highlands',
                child: Text('Thử nghiệm: Hóa đơn Highlands Coffee'),
              ),
              const PopupMenuItem(
                value: 'winmart',
                child: Text('Thử nghiệm: Hóa đơn WinMart+ Siêu thị'),
              ),
              const PopupMenuItem(
                value: 'grab',
                child: Text('Thử nghiệm: Hóa đơn Grab chuyến đi'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nút chọn nguồn ảnh
            _buildSourceButtons(),
            const SizedBox(height: 16),

            // Trạng thái quét & Hình ảnh
            if (_isProcessing)
              _buildProcessingIndicator()
            else if (_imageFile != null)
              _buildImagePreview(),

            const SizedBox(height: 16),

            // Kết quả Heuristic bóc tách
            if (_parsedReceipt != null) ...[
              _buildConfidenceBanner(),
              const SizedBox(height: 16),
              _buildVerificationForm(),
              const SizedBox(height: 16),
              _buildHeuristicLogsAccordion(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveExpense,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Xác nhận & Lưu Chi Tiêu'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickAndProcessImage(ImageSource.camera),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Chụp ảnh'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickAndProcessImage(ImageSource.gallery),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Thư viện'),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Đang chạy Google ML Kit & Thuật toán Heuristic Regex...',
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        _imageFile!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildConfidenceBanner() {
    final conf = _parsedReceipt!.overallConfidence;
    final color = conf >= 0.8
        ? Colors.green
        : (conf >= 0.5 ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Độ tin cậy trích xuất: ${(conf * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  'Cửa hàng: ${(_parsedReceipt!.fieldConfidences['merchant']! * 100).toStringAsFixed(0)}% | '
                  'Số tiền: ${(_parsedReceipt!.fieldConfidences['amount']! * 100).toStringAsFixed(0)}% | '
                  'Ngày: ${(_parsedReceipt!.fieldConfidences['date']! * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kiểm tra & Hiệu chỉnh thông tin',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          // Tên nơi bán
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Tên cửa hàng / Người bán',
              prefixIcon: Icon(Icons.store_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Số tiền
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tổng số tiền (VNĐ)',
              prefixIcon: Icon(Icons.attach_money_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Ngày giao dịch
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Ngày giao dịch',
                prefixIcon: Icon(Icons.calendar_today_rounded),
                border: OutlineInputBorder(),
              ),
              child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
            ),
          ),
          const SizedBox(height: 12),

          // Danh mục chi tiêu
          DropdownButtonFormField<ExpenseCategory>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Danh mục chi tiêu',
              prefixIcon: Icon(Icons.category_rounded),
              border: OutlineInputBorder(),
            ),
            items: ExpenseCategory.values.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Row(
                  children: [
                    Icon(cat.icon, color: cat.color, size: 20),
                    const SizedBox(width: 8),
                    Text(cat.label),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 12),

          // Ghi chú
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              prefixIcon: Icon(Icons.edit_note_rounded),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeuristicLogsAccordion() {
    return ExpansionTile(
      title: const Text(
        'Nhật ký phân tích Heuristic Regex',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _parsedReceipt!.heuristicLogs.map((log) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $log',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- Dữ liệu hóa đơn mẫu kiểm thử offline ---
  static const String _sampleHighlands = '''
HIGHLANDS COFFEE
123 Lê Lợi, Phường Bến Nghé, Quận 1, TP.HCM
HÓA ĐƠN BÁN HÀNG
Ngày: 19/09/2023  10:15
1 Phin Sữa Đá (L)          39.000 đ
1 Bánh Phô Mai Cà Phê      29.000 đ
Tổng cộng:                 68.000 đ
Tiền khách đưa:           100.000 đ
Tiền thối lại:             32.000 đ
''';

  static const String _sampleWinMart = '''
SIÊU THỊ WINMART+
ĐC: 45 Nguyễn Huệ, Quận 1
MST: 0104918404
PHIẾU THANH TOÁN
Ngày 22/09/2023
Sữa tươi tiệt trùng         36.000
Bánh mì sandwich           24.000
Trứng gà Ba Huân           32.000
Tổng thanh toán:           92.000 đ
Khách trả:                100.000
''';

  static const String _sampleGrab = '''
GRAB VIETNAM
Chuyến xe GrabCar
Mã chuyến: A-92812739
Ngày: 25/09/2023 08:30
Cước phí chuyến đi:       125.000 đ
Khuyến mãi:               -15.000 đ
Tổng tiền thanh toán:     110.000 đ
Thanh toán qua Ví Moca
''';
}
