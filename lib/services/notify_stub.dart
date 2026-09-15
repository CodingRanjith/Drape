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
