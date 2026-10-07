import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/category_model.dart';
import '../services/database_service.dart';
import '../widgets/custom_charts/interactive_pie_chart.dart';
import '../widgets/custom_charts/interactive_bar_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  Map<ExpenseCategory, double> _categoryData = {};
  Map<DateTime, double> _dailyData = {};
  double _totalSpending = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    final categoryTotals = await DatabaseService.instance.getCategoryTotals();
    final dailyTotals = await DatabaseService.instance.getDailyTotalsLast7Days();
    final total = await DatabaseService.instance.getTotalSpending();

    if (mounted) {
      setState(() {
        _categoryData = categoryTotals;
        _dailyData = dailyTotals;
        _totalSpending = total;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân Tích & Báo Cáo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnalyticsData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalyticsData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thẻ tóm tắt
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng chi tiêu ghi nhận',
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currencyFormatter.format(_totalSpending),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics_rounded,
                              color: Color(0xFF4F46E5),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // PHẦN 1: Biểu đồ tròn CustomPainter
                    _buildSectionHeader(
                      'Cơ cấu chi tiêu theo Danh mục',
                      'Vẽ bằng CustomPainter • Chạm vào từng lát cắt để xem chi tiết',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: InteractivePieChart(data: _categoryData),
                    ),
                    const SizedBox(height: 24),

                    // PHẦN 2: Biểu đồ cột CustomPainter
                    _buildSectionHeader(
                      'Chi tiêu 7 ngày gần nhất',
                      'Vẽ bằng CustomPainter • Chạm vào cột để xem Tooltip số tiền',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: InteractiveBarChart(data: _dailyData),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
