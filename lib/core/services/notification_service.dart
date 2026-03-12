import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // 1. Khai báo tường minh kiểu dữ liệu để tránh lỗi "0 allowed"
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;

    // Cấu hình Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Cấu hình iOS/macOS (Darwin)
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    // Khởi tạo plugin
    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Xử lý khi click vào thông báo
        debugPrint("Notification payload: ${response.payload}");
      },
    );

    await requestPermissions();
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
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
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Cấu hình Android chi tiết
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'taskmate_channel_id',
      'TaskMate Notifications',
      channelDescription: 'Notifications for TaskMate events',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    // Cấu hình iOS chi tiết
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

    // SỬA LỖI CHIẾN THUẬT: 
    // Nếu Codemagic vẫn báo lỗi "0 allowed", chúng ta gọi hàm show với đầy đủ tham số có tên (nếu có)
    // hoặc đảm bảo không có bất kỳ sự nhầm lẫn nào về kiểu dữ liệu.
    try {
      await _notificationsPlugin.show(
        id,      // positional argument 1
        title,   // positional argument 2
        body,    // positional argument 3
        details, // positional argument 4
        payload: payload, // named argument
      );
    } catch (e) {
      debugPrint("Error showing notification: $e");
    }
  }
}s