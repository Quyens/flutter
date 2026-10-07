# 🧾 Dự Án: Quản Lý Chi Phí & Phân Tích Hóa Đơn Bằng OCR (Flutter & Dart)

> **Mục tiêu học tập:**  
> 1. Phát triển ứng dụng tài chính cá nhân với **AI On-Device (Trí tuệ nhân tạo chạy ngoại tuyến trên thiết bị)**.  
> 2. Tích hợp **Google ML Kit Text Recognition** để trích xuất văn bản hóa đơn ngoại tuyến 100% không cần gửi dữ liệu lên máy chủ, bảo vệ quyền riêng tư người dùng.  
> 3. Xây dựng **Trình phân tích Heuristic Regex (Heuristic Rule-based Regex Engine)** thông minh để nhận diện: **Tên người bán (Merchant)**, **Ngày giao dịch (Date)**, **Tổng số tiền (Total Amount)** và tự động gợi ý **Danh mục chi tiêu**.  
> 4. Tự thiết kế và dựng **Biểu đồ tròn (Pie Chart)** & **Biểu đồ cột (Bar Chart)** động, có tương tác chạm (Hit-testing) hoàn toàn bằng **`CustomPainter`** (không phụ thuộc thư viện biểu đồ bên thứ 3).  
> 5. Quản lý dữ liệu bền vững bằng SQLite (`sqflite`).  
> 6. Cấu hình hoàn chỉnh cho **iOS Xcode Build** và **Android**.

---

## 📁 Cấu Trúc Mã Nguồn (Clean Architecture)

```
lib/
├── main.dart                               # Khởi tạo App & đa ngôn ngữ tiếng Việt (intl)
├── models/
│   ├── category_model.dart                 # Enum danh mục chi tiêu, màu sắc & icon
│   ├── expense_model.dart                  # Model chi tiêu, chuyển đổi SQLite map
│   └── parsed_receipt_model.dart           # Model kết quả bóc tách OCR kèm độ tin cậy
├── services/
│   ├── heuristic_receipt_parser.dart       # Thuật toán Heuristic Regex bóc tách hóa đơn
│   ├── ocr_service.dart                    # Wrapper Google ML Kit Text Recognition
│   └── database_service.dart               # Quản lý SQLite CRUD & thống kê số liệu
├── theme/
│   └── app_theme.dart                      # Design System phong cách Fintech hiện đại
├── widgets/
│   ├── summary_card.dart                   # Thẻ tổng quan số dư với hiệu ứng chuyển sắc
│   ├── expense_tile.dart                   # Item chi tiêu có chức năng vuốt để xóa
│   └── custom_charts/
│       ├── interactive_pie_chart.dart      # CustomPainter biểu đồ tròn tương tác
│       └── interactive_bar_chart.dart      # CustomPainter biểu đồ cột tương tác
└── screens/
    ├── home_screen.dart                    # Màn hình chính & danh sách giao dịch
    ├── scan_receipt_screen.dart            # Màn hình chụp/quét OCR & chỉnh sửa trực tiếp
    ├── expense_detail_screen.dart          # Màn hình thêm/sửa chi tiêu thủ công
    └── analytics_screen.dart               # Màn hình báo cáo chi tiết kèm biểu đồ CustomPainter
```

---

## 🧠 1. Thuật Toán Heuristic Regex Parser

Hóa đơn thực tế thường có định dạng không đồng nhất, thứ tự dòng bị xáo trộn qua OCR và nhiều con số gây nhiễu (mã hóa đơn, số điện thoại, tiền khách đưa, tiền thừa). Hệ thống triển khai thuật toán Heuristic đa cấp tại [`lib/services/heuristic_receipt_parser.dart`](file:///c:/Users/quyen/Documents/Thư%20mục%20mới/lib/services/heuristic_receipt_parser.dart):

### A. Nhận diện Tên người bán (Merchant Name)
- **Heuristic Vị trí:** Thường nằm ở 1 - 5 dòng đầu tiên.
- **Bộ lọc loại trừ nhiễu (Negative Filter):** Bỏ qua các dòng chứa từ khóa tiêu đề chung (`HÓA ĐƠN BÁN HÀNG`, `RECEIPT`, `PHIẾU TÍNH TIỀN`, `CỘNG HÒA XÃ HỘI...`), địa chỉ (`Đ/c`, `Quận`, `Đường`), số điện thoại (`Tel`, `Hotline`), mã số thuế (`MST`).
- **Ma trận chấm điểm (Scoring Matrix):**
  - Khớp thương hiệu phổ biến (`Highlands`, `WinMart`, `Phúc Long`, `Starbucks`, `Circle K`, `Grab`...): **+60 điểm**.
  - Chứa tiền tố kinh doanh (`Cà phê`, `Nhà hàng`, `Quán`, `Siêu thị`, `Store`, `Shop`...): **+35 điểm**.
  - Dòng viết HOA toàn bộ: **+15 điểm**.
  - Chứa nhiều chữ số: **-25 điểm**.

### B. Nhận diện Ngày giao dịch (Transaction Date)
Sử dụng tổ hợp nhiều biểu thức chính quy (Regex):
1. **Chuẩn Việt Nam & Quốc tế (`dd/MM/yyyy`, `dd-MM-yyyy`, `dd.MM.yyyy`):**
   ```dart
   RegExp(r'(?:ngày|date)?\s*[:\s]?\s*(\b[0-3]?[0-9])[\/\-\.]([0-1]?[0-9])[\/\-\.](20[1-3][0-9]|[1-3][0-9]\b)')
   ```
2. **Chuẩn ISO (`yyyy-MM-dd`):**
   ```dart
   RegExp(r'(\b20[1-3][0-9])[\/\-\.]([0-1]?[0-9])[\/\-\.]([0-3]?[0-9]\b)')
   ```
3. **Văn bản tiếng Việt tự nhiên (`Ngày dd tháng MM năm yyyy`):**
   ```dart
   RegExp(r'(?:ngày|ngay)\s*(\d{1,2})\s*(?:tháng|thg|th)\s*(\d{1,2})(?:\s*(?:năm|nam)\s*(20\d{2}))?')
   ```
- Đi kèm hàm kiểm tra tính hợp lệ của ngày (`day <= 31`, `month <= 12`, `2018 <= year <= 2035`).

### C. Nhận diện Tổng số tiền (Total Amount)
- **Trọng số từ khóa tích cực:** Dòng chứa `tổng cộng`, `tổng tiền`, `thanh toán`, `grand total`, `amount due` được cộng **+50 điểm**.
- **Loại trừ "bẫy" số tiền:** Dòng chứa `tiền khách đưa`, `khách trả`, `tiền thối lại`, `tiền thừa`, `change`, `chiết khấu` bị phạt **-60 điểm**.
- **Regex số tiền đa dạng:** Xử lý cả dấu chấm hàng nghìn (`150.000`), dấu phẩy (`150,000`), khoảng trắng (`150 000`) và tiền tệ kèm ký hiệu (`đ`, `VNĐ`, `$`).
- **Thuật toán dòng liền kề:** Nếu từ khóa "Tổng cộng" ở dòng $i$ và giá trị số nằm ở dòng $i+1$, hệ thống tự động liên kết với điểm ưu tiên cao.

---

## 🎨 2. Thiết Kế Biểu Đồ Động Bằng `CustomPainter`

Dự án không dùng bất kỳ thư viện biểu đồ bên thứ 3 nào, thỏa mãn yêu cầu cốt lõi về Custom Canvas Rendering:

### A. Biểu đồ tròn tương tác (`InteractivePieChart`)
- **Giải thuật Lượng giác:**
  - Tọa độ tâm: $C = (\frac{W}{2}, \frac{H}{2})$, Bán kính ngoài $R = \min(W, H) \times 0.425$.
  - Bán kính lỗ Donut trong: $r = R \times 0.58$.
  - Góc quét của từng danh mục: $\theta_i = \frac{\text{Amount}_i}{\text{Total}} \times 2\pi \times \text{animationProgress}$.
  - Vẽ nan quạt bằng `canvas.drawArc(rect, startAngle, sweepAngle, true, paint)`.
- **Hiệu ứng Nhô Lát Cắt (Exploded Slice):**
  - Khi người dùng chạm vào một phần lát cắt, lát cắt đó sẽ dịch chuyển ra ngoài theo góc phân giác:
    $$\Delta X = \cos(\text{bisector}) \times 8.0, \quad \Delta Y = \sin(\text{bisector}) \times 8.0$$
- **Nhận diện cảm ứng (Hit-testing):**
  - Tính khoảng cách từ điểm chạm $P(x, y)$ đến tâm: $d = \sqrt{(x - C_x)^2 + (y - C_y)^2}$.
  - Nếu $r \le d \le R$, tính góc chạm bằng hàm ngược hàm tiếp tuyến:
    $$\alpha = \text{atan2}(y - C_y, x - C_x)$$
  - Xác định chính xác lát cắt được chọn để làm nổi bật và hiển thị thông tin chi tiết tại tâm Donut.

### B. Biểu đồ cột tương tác (`InteractiveBarChart`)
- **Vẽ trục tọa độ & Grid lines:** Tính toán khoảng chia tự động dựa trên giá trị lớn nhất ($\text{Max} \times 1.2$).
- **Bo tròn đỉnh cột:** Sử dụng `RRect.fromRectAndCorners(..., topLeft: Radius.circular(6), topRight: Radius.circular(6))`.
- **Chuyển sắc Gradient:** Tạo `LinearGradient` từ màu tím đậm sang tím sáng hoặc cam/đỏ khi được chọn.
- **Tooltip nổi (Floating Tooltip):** Khi chạm vào cột, hệ thống tính toán vị trí đỉnh cột và vẽ hộp thoại nổi chứa chính xác số tiền VNĐ.

---

## 📱 3. Hướng Dẫn Cấu Hình iOS Xcode & Android

### A. Cấu hình iOS (Xcode Build)
1. **Quyền hạn trong [`ios/Runner/Info.plist`](file:///c:/Users/quyen/Documents/Thư%20mục%20mới/ios/Runner/Info.plist):**
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Ứng dụng cần quyền sử dụng Camera để chụp ảnh hóa đơn và phân tích OCR ngoại tuyến.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Ứng dụng cần quyền truy cập Thư viện ảnh để chọn ảnh biên lai cần bóc tách chi phí.</string>
   ```
2. **Cấu hình [`ios/Podfile`](file:///c:/Users/quyen/Documents/Thư%20mục%20mới/ios/Podfile):**
   - Google ML Kit yêu cầu iOS Target tối thiểu là **iOS 13.0**:
     ```ruby
     platform :ios, '13.0'
     ```
   - Trong block `post_install`:
     ```ruby
     installer.pods_project.targets.each do |target|
       flutter_additional_ios_build_settings(target)
       target.build_configurations.each do |config|
         config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
         config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
       end
     end
     ```

### B. Cấu hình Android
1. **Quyền hạn trong [`android/app/src/main/AndroidManifest.xml`](file:///c:/Users/quyen/Documents/Thư%20mục%20mới/android/app/src/main/AndroidManifest.xml):**
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
   <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
   ```
2. **Tự động tải mô hình OCR:**
   ```xml
   <meta-data
       android:name="com.google.mlkit.vision.DEPENDENCIES"
       android:value="ocr" />
   ```
3. `minSdkVersion`: Tối thiểu là **21**.

---

## 🚀 4. Hướng Dẫn Chạy & Kiểm Thử Ứng Dụng

### Bước 1: Cài đặt thư viện dependencies
```bash
flutter pub get
```

### Bước 2: Chạy bộ kiểm thử tự động (Unit Tests)
Dự án đi kèm bộ test xác thực thuật toán Heuristic Regex với nhiều định dạng hóa đơn (Highlands, WinMart, Starbucks, Grab):
```bash
flutter test
```

### Bước 3: Chạy ứng dụng trên thiết bị / máy ảo
```bash
# Chạy trên thiết bị kết nối
flutter run

# Hoặc mở thư mục ios trong Xcode trên máy Mac:
open ios/Runner.xcworkspace
```

> 💡 **Tính năng Thử nghiệm Tiện ích (Demo Sample Receipts):**  
> Trong màn hình **Quét Hóa Đơn OCR**, nhấn vào biểu tượng kính lúp / bình thí nghiệm 🧪 ở góc trên bên phải để kiểm thử ngay lập tức các mẫu hóa đơn thực tế (Highlands, WinMart, Grab) mà không cần phải chụp ảnh thật khi dùng máy ảo!
