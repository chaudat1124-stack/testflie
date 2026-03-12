import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Khởi tạo plugin
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return; // Không chạy trên web

    // 1. Cấu hình cho Android (icon lấy từ drawable/app_icon hoặc @mipmap/ic_launcher)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. Cấu hình cho iOS/macOS
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false, // Sẽ yêu cầu permission thủ công sau
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    // 3. Khởi tạo
    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Xử lý logic khi người dùng chạm vào thông báo ở đây
        debugPrint("Notification clicked with payload: ${response.payload}");
      },
    );

    // 4. Xin quyền (Permissions)
    await requestPermissions();
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;

    // Xin quyền cho Android (đặc biệt là Android 13+)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } 
    // Xin quyền cho iOS
    else if (defaultTargetPlatform == TargetPlatform.iOS || 
             defaultTargetPlatform == TargetPlatform.macOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  static Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Cấu hình chi tiết cho Android
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'taskmate_channel_id', // ID kênh (duy nhất)
      'TaskMate Notifications', // Tên kênh hiển thị trong cài đặt máy
      channelDescription: 'Notifications for TaskMate events',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    // Cấu hình chi tiết cho iOS
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // SỬA LỖI TẠI ĐÂY: Đảm bảo truyền đúng tham số
    // Nếu vẫn lỗi "0 allowed", hãy kiểm tra xem bạn có đang import nhầm thư viện nào khác không.
    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload, // Thêm payload nếu cần truyền dữ liệu ngầm
    );
  }
}