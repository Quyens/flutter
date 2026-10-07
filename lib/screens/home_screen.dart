import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/database_service.dart';
import '../widgets/expense_tile.dart';
import '../widgets/summary_card.dart';
import 'analytics_screen.dart';
import 'expense_detail_screen.dart';
import 'scan_receipt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Expense> _expenses = [];
  double _totalAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final list = await DatabaseService.instance.getAllExpenses();
    final total = await DatabaseService.instance.getTotalSpending();

    if (mounted) {
      setState(() {
        _expenses = list;
        _totalAmount = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _openScanScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanReceiptScreen()),
    );
    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _openAddManualScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExpenseDetailScreen()),
    );
    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _openDetailScreen(Expense expense) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ExpenseDetailScreen(expense: expense)),
    );
    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _deleteExpense(int id) async {
    await DatabaseService.instance.deleteExpense(id);
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense & OCR Tracker',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            Text(
              todayStr,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Báo cáo & Biểu đồ CustomPainter',
            icon: const Icon(Icons.pie_chart_rounded, color: Color(0xFF4F46E5)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Thẻ tóm tắt tổng tiền & quét nhanh
                  SummaryCard(
                    totalAmount: _totalAmount,
                    transactionCount: _expenses.length,
                    onScanPressed: _openScanScreen,
                  ),
                  const SizedBox(height: 20),

                  // Các nút thao tác nhanh
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.camera_alt_rounded,
                          title: 'Quét Hóa Đơn',
                          color: const Color(0xFF4F46E5),
                          onTap: _openScanScreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.edit_note_rounded,
                          title: 'Nhập Thủ Công',
                          color: const Color(0xFF06B6D4),
                          onTap: _openAddManualScreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.bar_chart_rounded,
                          title: 'Xem Biểu Đồ',
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Tiêu đề danh sách giao dịch gần đây
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Giao dịch gần đây',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Vuốt sang trái để xóa',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Danh sách các khoản chi
                  if (_expenses.isEmpty)
                    _buildEmptyState()
                  else
                    ..._expenses.map((expense) => ExpenseTile(
                          expense: expense,
                          onTap: () => _openDetailScreen(expense),
                          onDelete: () {
                            if (expense.id != null) {
                              _deleteExpense(expense.id!);
                            }
                          },
                        )),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanScreen,
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Quét Hóa Đơn'),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.receipt_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Chưa có khoản chi tiêu nào',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhấn nút Quét Hóa Đơn để bắt đầu chụp biên lai!',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
