import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo định dạng ngày tháng tiếng Việt cho thư viện intl
  await initializeDateFormatting('vi_VN', null);
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense & OCR Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
