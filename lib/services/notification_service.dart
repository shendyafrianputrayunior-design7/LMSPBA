import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const int learningReminderId = 1001;
  static const int testNotificationId = 1002;

  static const String channelId = 'lms_notifications';
  static const String channelName = 'LMS Notifications';
  static const String channelDescription =
      'Notifications and learning reminders from LMS';

  bool _initialized = false;

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    final timezone =
    await FlutterTimezone.getLocalTimezone();

    tz.setLocalLocation(
      tz.getLocation(timezone.identifier),
    );

    const androidSettings =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings =
    InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: initializationSettings,
    );

    _initialized = true;
  }

  // ============================================================
  // REQUEST PERMISSION
  // ============================================================

  Future<bool> requestPermission() async {
    await initialize();

    final android =
    _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final permission =
    await android?.requestNotificationsPermission();

    return permission ?? true;
  }

  // ============================================================
  // NOTIFICATION DETAILS
  // ============================================================

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }

  // ============================================================
  // TEST NOTIFICATION
  // ============================================================

  Future<void> showTestNotification() async {
    await initialize();

    await _notifications.show(
      id: testNotificationId,
      title: 'Notifikasi LMS',
      body: 'Notifikasi berhasil diaktifkan.',
      notificationDetails: _notificationDetails(),
    );
  }

  // ============================================================
  // SCHEDULE LEARNING REMINDER
  // ============================================================

  Future<void> scheduleLearningReminder({
    required int hour,
    required int minute,
  }) async {
    await initialize();

    // Hapus reminder lama agar tidak terjadi
    // duplicate notification.
    await _notifications.cancel(
      id: learningReminderId,
    );

    final now = tz.TZDateTime.now(
      tz.local,
    );

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Kalau waktu hari ini sudah lewat,
    // mulai dari besok.
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(
        const Duration(days: 1),
      );
    }

    await _notifications.zonedSchedule(
      id: learningReminderId,
      title: 'Waktu Belajar',
      body: 'Yuk lanjutkan belajar di LMS hari ini.',
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails(),
      androidScheduleMode:
      AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
      DateTimeComponents.time,
    );
  }

  // ============================================================
  // CANCEL LEARNING REMINDER
  // ============================================================

  Future<void> cancelLearningReminder() async {
    await initialize();

    await _notifications.cancel(
      id: learningReminderId,
    );
  }

  // ============================================================
  // CANCEL ALL
  // ============================================================

  Future<void> cancelAll() async {
    await initialize();

    await _notifications.cancelAll();
  }
}