import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final _plugin = FlutterLocalNotificationsPlugin();
var _ready = false;

const waterReminderPayload = 'water-reminder';
const waterDrankPayload = 'water-drank';
const waterDrankActionId = 'water_drank';
const pendingWaterDrankKey = 'pending_water_drank';

@pragma('vm:entry-point')
void _onBackgroundNotification(NotificationResponse response) {
  if (response.actionId != waterDrankActionId &&
      response.payload != waterDrankPayload) {
    return;
  }
  SharedPreferences.getInstance().then((prefs) {
    prefs.setBool(pendingWaterDrankKey, true);
  });
}

String? _payloadFromResponse(NotificationResponse response) {
  if (response.actionId == waterDrankActionId) return waterDrankPayload;
  final payload = response.payload;
  if (payload != null && payload.isNotEmpty) return payload;
  return null;
}

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
        if (response.actionId == waterDrankActionId) {
          onAlarm(waterDrankPayload);
          return;
        }
        final id = _payloadFromResponse(response);
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

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(pendingWaterDrankKey) == true) {
      await prefs.setBool(pendingWaterDrankKey, false);
      onAlarm(waterDrankPayload);
    }

    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      if (response.actionId == waterDrankActionId) {
        onAlarm(waterDrankPayload);
      } else {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onAlarm(payload);
      }
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

Future<void> showLocalNoticeImpl({
  required int id,
  required String title,
  required String body,
  String? payload,
}) async {
  if (!_ready) return;
  try {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'mine_metal_rates',
          'Gold & silver rates',
          channelDescription: 'Daily morning gold and silver price changes',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  } catch (e, st) {
    debugPrint('Could not show notice: $e\n$st');
  }
}

Future<void> scheduleDailyMetalBriefingImpl({
  required int id,
  required int hour,
  required int minute,
  required String title,
  required String body,
  required String payload,
}) async {
  if (!_ready) return;
  try {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    await _plugin.cancel(id);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(next.toUtc(), tz.UTC),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'mine_metal_rates',
          'Gold & silver rates',
          channelDescription: 'Daily morning gold and silver price changes',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  } catch (e, st) {
    debugPrint('Could not schedule metal briefing: $e\n$st');
  }
}

Future<void> scheduleWaterReminderImpl({
  required int id,
  required DateTime at,
  required String title,
  required String body,
  required String payload,
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          'mine_water_v1',
          'Water reminders',
          channelDescription: 'Hydration glass reminders with water sound',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.reminder,
          icon: '@drawable/ic_stat_water',
          playSound: true,
          enableVibration: true,
          sound: const RawResourceAndroidNotificationSound('water_chime'),
          audioAttributesUsage: AudioAttributesUsage.assistanceSonification,
          styleInformation: BigTextStyleInformation(body),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              waterDrankActionId,
              'I drank',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  } catch (e, st) {
    debugPrint('Could not schedule water reminder: $e\n$st');
  }
}

Future<void> showWaterReminderNoticeImpl({
  required int id,
  required String title,
  required String body,
  required String payload,
}) async {
  if (!_ready) return;
  try {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'mine_water_v1',
          'Water reminders',
          channelDescription: 'Hydration glass reminders with water sound',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.reminder,
          icon: '@drawable/ic_stat_water',
          playSound: true,
          enableVibration: true,
          sound: const RawResourceAndroidNotificationSound('water_chime'),
          audioAttributesUsage: AudioAttributesUsage.assistanceSonification,
          styleInformation: BigTextStyleInformation(body),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              waterDrankActionId,
              'I drank',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: payload,
    );
  } catch (e, st) {
    debugPrint('Could not show water notice: $e\n$st');
  }
}
