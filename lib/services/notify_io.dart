import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final _plugin = FlutterLocalNotificationsPlugin();
var _ready = false;

@pragma('vm:entry-point')
void _onBackgroundNotification(NotificationResponse response) {}

Future<void> initEventAlarmsImpl({
  required void Function(String eventId) onAlarm,
}) async {
  try {
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onAlarm(id);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await Permission.notification.request();

    _ready = true;

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      onAlarm(payload);
    }
  } catch (e, st) {
    debugPrint('Alarm setup failed: $e\n$st');
  }
}

Future<void> scheduleEventAlarmImpl({
  required int id,
  required DateTime at,
  required String title,
  required String body,
  required String eventId,
}) async {
  if (!_ready) return;
  if (!at.isAfter(DateTime.now().subtract(const Duration(seconds: 5)))) return;
  try {
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at.toUtc(), tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mine_alarms',
          'Event alarms',
          channelDescription: 'Birthday, function and party reminders',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: eventId,
    );
  } catch (e, st) {
    debugPrint('Could not set alarm: $e\n$st');
  }
}

Future<void> cancelEventAlarmImpl(int id) async {
  if (!_ready) return;
  try {
    await _plugin.cancel(id);
  } catch (e) {
    debugPrint('Could not cancel alarm: $e');
  }
}
