import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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

    // SỬA LỖI DÒNG 31: Gọi initialize
    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}");
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
    } else {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> showNotification({
    required int id, // Tham số này bắt buộc
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'taskmate_channel',
      'TaskMate Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // SỬA LỖI DÒNG 93: Truyền tham số chuẩn
    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }
}