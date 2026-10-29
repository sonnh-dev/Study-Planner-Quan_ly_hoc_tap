import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (kIsWeb) return;
    timezone_data.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(local.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        windows: WindowsInitializationSettings(
          appName: 'Study Planner',
          appUserModelId: 'com.duy.studyplanner',
          guid: 'f6c628fc-8f6a-4bc1-8e70-a6e342e6fb98',
        ),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  Future<void> schedule(int id, String title, DateTime when) async {
    if (kIsWeb) return;
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: 'Đến giờ học rồi',
      body: title,
      scheduledDate: timezone.TZDateTime.from(when, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_reminders',
          'Nhắc lịch học',
          channelDescription: 'Thông báo lịch học và hẹn giờ',
          importance: Importance.max,
          priority: Priority.high,
        ),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    if (!kIsWeb) await _plugin.cancel(id: id);
  }
}
