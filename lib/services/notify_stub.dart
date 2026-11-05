Future<void> initEventAlarmsImpl({
  required void Function(String eventId) onAlarm,
}) async {}

Future<void> scheduleEventAlarmImpl({
  required int id,
  required DateTime at,
  required String title,
  required String body,
  required String eventId,
}) async {}

Future<void> cancelEventAlarmImpl(int id) async {}

Future<void> showLocalNoticeImpl({
  required int id,
  required String title,
  required String body,
  String? payload,
}) async {}

Future<void> scheduleDailyMetalBriefingImpl({
  required int id,
  required int hour,
  required int minute,
  required String title,
  required String body,
  required String payload,
}) async {}
