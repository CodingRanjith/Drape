import 'notify_stub.dart'
    if (dart.library.io) 'notify_io.dart'
    if (dart.library.html) 'notify_web.dart';

export 'notify_stub.dart'
    if (dart.library.io) 'notify_io.dart'
    if (dart.library.html) 'notify_web.dart';

Future<void> initEventAlarms({
  required void Function(String eventId) onAlarm,
}) => initEventAlarmsImpl(onAlarm: onAlarm);

Future<void> scheduleEventAlarm({
  required int id,
  required DateTime at,
  required String title,
  required String body,
  required String eventId,
}) => scheduleEventAlarmImpl(
  id: id,
  at: at,
  title: title,
  body: body,
  eventId: eventId,
);

Future<void> cancelEventAlarm(int id) => cancelEventAlarmImpl(id);
