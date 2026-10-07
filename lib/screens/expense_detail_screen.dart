import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../services/database_service.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final Expense? expense;

  const ExpenseDetailScreen({super.key, this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  late ExpenseCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(0) : '',
    );
    _noteController = TextEditingController(text: e?.note ?? '');
    _selectedDate = e?.dateTime ?? DateTime.now();
    _selectedCategory = e?.category ?? ExpenseCategory.foodAndDining;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (amount == null || amount <= 0) return;

    final expense = Expense(
      id: widget.expense?.id,
      title: _titleController.text.trim(),
      amount: amount,
      category: _selectedCategory,
      dateTime: _selectedDate,
      note: _noteController.text.trim(),
      rawOcrText: widget.expense?.rawOcrText,
      imagePath: widget.expense?.imagePath,
    );

    if (widget.expense == null) {
      await DatabaseService.instance.insertExpense(expense);
    } else {
      await DatabaseService.instance.updateExpense(expense);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chi Tiết Khoản Chi' : 'Thêm Khoản Chi Mới'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả / Tên người bán *',
                  prefixIcon: Icon(Icons.store_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VNĐ) *',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Vui lòng nhập số tiền';
                  final num = double.tryParse(val.replaceAll(RegExp(r'[^0-9.]'), ''));
                  if (num == null || num <= 0) return 'Số tiền không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm',
                  prefixIcon: Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.expense?.rawOcrText != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Văn bản OCR gốc của hóa đơn'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.expense!.rawOcrText!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveExpense,
                icon: const Icon(Icons.save_rounded),
                label: Text(isEditing ? 'Lưu Thay Đổi' : 'Thêm Chi Tiêu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
