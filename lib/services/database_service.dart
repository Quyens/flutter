import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses_ocr.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date_time TEXT NOT NULL,
        note TEXT,
        raw_ocr_text TEXT,
        image_path TEXT
      )
    ''');

    // Chèn dữ liệu mẫu ban đầu để người dùng trải nghiệm ngay biểu đồ CustomPainter
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now();
    final sampleData = [
      {
        'title': 'Highlands Coffee',
        'amount': 154440.0,
        'category': ExpenseCategory.foodAndDining.label,
        'date_time': now.subtract(const Duration(days: 0, hours: 2)).toIso8601String(),
        'note': 'Hóa đơn quét OCR - 2 ly cà phê & bánh mì que',
      },
      {
        'title': 'WinMart+ Cống Quỳnh',
        'amount': 382000.0,
        'category': ExpenseCategory.shopping.label,
        'date_time': now.subtract(const Duration(days: 1, hours: 4)).toIso8601String(),
        'note': 'Thực phẩm gia đình tuần này',
      },
      {
        'title': 'Grab Car đi sân bay',
        'amount': 210000.0,
        'category': ExpenseCategory.transport.label,
        'date_time': now.subtract(const Duration(days: 2, hours: 6)).toIso8601String(),
        'note': 'Chuyến xe đón người thân',
      },
      {
        'title': 'Nhà thuốc Long Châu',
        'amount': 145000.0,
        'category': ExpenseCategory.health.label,
        'date_time': now.subtract(const Duration(days: 3)).toIso8601String(),
        'note': 'Vitamin C và thuốc cảm',
      },
      {
        'title': 'Vé xem phim CGV',
        'amount': 220000.0,
        'category': ExpenseCategory.entertainment.label,
        'date_time': now.subtract(const Duration(days: 4)).toIso8601String(),
        'note': '2 vé xem phim cuối tuần',
      },
      {
        'title': 'Hóa đơn tiền điện EVN',
        'amount': 650000.0,
        'category': ExpenseCategory.bills.label,
        'date_time': now.subtract(const Duration(days: 5)).toIso8601String(),
        'note': 'Thanh toán tiền điện tháng này',
      },
    ];

    for (final item in sampleData) {
      await db.insert('expenses', item);
    }
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final result = await db.query('expenses', orderBy: 'date_time DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<double> getTotalSpending() async {
    final db = await database;
    final result = await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Lấy tổng chi tiêu phân bổ theo từng Danh Mục (phục vụ vẽ Pie Chart)
  Future<Map<ExpenseCategory, double>> getCategoryTotals() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM expenses
      GROUP BY category
    ''');

    final Map<ExpenseCategory, double> map = {};
    for (final row in result) {
      final cat = ExpenseCategory.fromString(row['category'] as String?);
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      map[cat] = (map[cat] ?? 0.0) + total;
    }
    return map;
  }

  /// Lấy tổng chi tiêu 7 ngày gần nhất (phục vụ vẽ Bar Chart)
  Future<Map<DateTime, double>> getDailyTotalsLast7Days() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));

    final result = await db.rawQuery('''
      SELECT date_time, amount
      FROM expenses
      WHERE date_time >= ?
      ORDER BY date_time ASC
    ''', [sevenDaysAgo.toIso8601String()]);

    final Map<DateTime, double> dailyMap = {};
    // Khởi tạo trước 7 ngày với giá trị 0
    for (int i = 0; i < 7; i++) {
      final d = sevenDaysAgo.add(Duration(days: i));
      dailyMap[DateTime(d.year, d.month, d.day)] = 0.0;
    }

    for (final row in result) {
      final dt = DateTime.parse(row['date_time'] as String);
      final dayKey = DateTime(dt.year, dt.month, dt.day);
      final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
      dailyMap[dayKey] = (dailyMap[dayKey] ?? 0.0) + amt;
    }

    return dailyMap;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
