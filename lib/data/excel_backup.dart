import 'dart:typed_data';

import '../models/bucket_list.dart';
import '../models/life.dart';
import '../models/wardrobe.dart';
import 'excel_sheet.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

String get excelBackupMime => _xlsxMime;

Map<String, List<List<String>>> excelSheetsOf({
  required UserProfile profile,
  required List<Garment> garments,
  WeekPlan? week,
  required List<LifeEvent> events,
  required List<PartyLook> partyLooks,
  required Set<String> completedDays,
  List<ClothSet> clothSets = const [],
  List<StyleBucketItem> bucketList = const [],
}) {
  return {
    'Profile': _profileSheet(profile),
    'Clothes': [
      _clothesHeader,
      ...garments.map(_clothesRow),
    ],
    'Events': [
      _eventsHeader,
      ...events.map(_eventRow),
    ],
    'Looks': [
      const ['id', 'name', 'occasion', 'createdAt'],
      ...partyLooks.map(
        (look) => [
          look.id,
          look.name,
          look.occasion.name,
          look.createdAt.toIso8601String(),
        ],
      ),
    ],
    'Sets': [
      const [
        'id',
        'name',
        'collection',
        'topId',
        'bottomId',
        'dressId',
        'outerwearId',
        'shoesId',
        'accessoryId',
        'tshirtId',
      ],
      ...clothSets.map(
        (set) => [
          set.id,
          set.name,
          set.collection.name,
          set.outfit.topId ?? '',
          set.outfit.bottomId ?? '',
          set.outfit.dressId ?? '',
          set.outfit.outerwearId ?? '',
          set.outfit.shoesId ?? '',
          set.outfit.accessoryId ?? '',
          set.outfit.tshirtId ?? '',
        ],
      ),
    ],
    'Bucket': [
      const ['id', 'title', 'note', 'vibe', 'createdAt', 'completedAt', 'starred'],
      ...bucketList.map(
        (item) => [
          item.id,
          item.title,
          item.note,
          item.vibe.name,
          item.createdAt.toIso8601String(),
          item.completedAt?.toIso8601String() ?? '',
          item.starred ? 'true' : 'false',
        ],
      ),
    ],
    'Days': [
      const ['date'],
      ...completedDays.map((day) => [day]),
    ],
    if (week != null)
      'Week': [
        const [
          'date',
          'locked',
          'worn',
          'topId',
          'bottomId',
          'dressId',
          'outerwearId',
          'shoesId',
          'accessoryId',
          'tshirtId',
        ],
        ...week.days.map(
          (day) => [
            dateKey(day.date),
            day.locked ? 'true' : 'false',
            day.worn ? 'true' : 'false',
            day.outfit?.topId ?? '',
            day.outfit?.bottomId ?? '',
            day.outfit?.dressId ?? '',
            day.outfit?.outerwearId ?? '',
            day.outfit?.shoesId ?? '',
            day.outfit?.accessoryId ?? '',
            day.outfit?.tshirtId ?? '',
          ],
        ),
      ],
  };
}

Uint8List encodeExcelBackup({
  required UserProfile profile,
  required List<Garment> garments,
  WeekPlan? week,
  required List<LifeEvent> events,
  required List<PartyLook> partyLooks,
  required Set<String> completedDays,
  List<ClothSet> clothSets = const [],
  List<StyleBucketItem> bucketList = const [],
}) {
  return SimpleXlsx.encode(
    excelSheetsOf(
      profile: profile,
      garments: garments,
      week: week,
      events: events,
      partyLooks: partyLooks,
      completedDays: completedDays,
      clothSets: clothSets,
      bucketList: bucketList,
    ),
  );
}

Map<String, dynamic> jsonFromExcel(Uint8List bytes) =>
    jsonFromExcelSheets(SimpleXlsx.decode(bytes));

Map<String, dynamic> jsonFromExcelSheets(Map<String, List<List<String>>> sheets) {
  final profileSheet = _sheetNamed(sheets, 'profile');
  final clothes = _table(_sheetNamed(sheets, 'clothes'));
  final events = _table(_sheetNamed(sheets, 'events'));
  final looks = _table(_sheetNamed(sheets, 'looks'));
  final sets = _table(_sheetNamed(sheets, 'sets'));
  final bucket = _table(_sheetNamed(sheets, 'bucket'));
  final days = _table(_sheetNamed(sheets, 'days'));
  final weekRows = _table(_sheetNamed(sheets, 'week'));

  final json = <String, dynamic>{
    'version': 1,
    'source': 'excel',
    'garments': clothes.map(_garmentFromRow).toList(),
    'events': events.map(_eventFromRow).toList(),
    'partyLooks': looks.map(_lookFromRow).toList(),
    'clothSets': sets.map(_setFromRow).toList(),
    'bucketList': bucket.map(_bucketFromRow).toList(),
    'completedDays': [
      for (final row in days)
        if ((row['date'] ?? '').trim().isNotEmpty) row['date']!.trim(),
    ],
  };

  final profile = _profileFromSheet(profileSheet);
  if (profile != null) json['profile'] = profile;

  if (weekRows.isNotEmpty) {
    final dates = weekRows
        .map((row) => DateTime.tryParse(row['date'] ?? ''))
        .whereType<DateTime>()
        .toList()
      ..sort();
    if (dates.isNotEmpty) {
      json['week'] = {
        'weekStart': dateKey(mondayOf(dates.first)),
        'days': weekRows.map(_dayFromRow).toList(),
      };
    }
  }

  return json;
}

List<List<String>> _profileSheet(UserProfile profile) => [
      const ['key', 'value'],
      ['name', profile.name],
      ['gender', profile.wearer.name],
      ['dateOfBirth', profile.dateOfBirth?.toIso8601String() ?? ''],
      ['heightCm', profile.heightCm?.toString() ?? ''],
      ['weightKg', profile.weightKg?.toString() ?? ''],
      ['description', profile.description],
      ['workdays', profile.workdays.join(',')],
      ['workStyle', profile.workStyle.name],
      ['minRepeatDays', '${profile.minRepeatDays}'],
      ['officeAlarmOn', profile.officeAlarmOn ? 'true' : 'false'],
      ['officeAlarmHour', '${profile.officeAlarmHour}'],
      ['officeAlarmMinute', '${profile.officeAlarmMinute}'],
      ['customShelves', profile.customShelves.join('|')],
    ];

const _clothesHeader = [
  'id',
  'name',
  'category',
  'wardrobeCategory',
  'topKind',
  'formality',
  'season',
  'colors',
  'notes',
  'cost',
  'favorite',
  'inLaundry',
  'wearCount',
  'createdAt',
  'lastWornAt',
  'customShelf',
  'styleCollection',
];

List<String> _clothesRow(Garment garment) => [
      garment.id,
      garment.name,
      garment.category.name,
      garment.wardrobeCategory.name,
      garment.topKind.name,
      garment.formality.name,
      garment.season.name,
      garment.colors.join(','),
      garment.notes,
      garment.cost?.toString() ?? '',
      garment.favorite ? 'true' : 'false',
      garment.inLaundry ? 'true' : 'false',
      '${garment.wearCount}',
      garment.createdAt.toIso8601String(),
      garment.lastWornAt?.toIso8601String() ?? '',
      garment.customShelf ?? '',
      garment.styleCollection?.name ?? '',
    ];

const _eventsHeader = [
  'id',
  'title',
  'kind',
  'at',
  'alarmOn',
  'notes',
  'garmentIds',
];

List<String> _eventRow(LifeEvent event) => [
      event.id,
      event.title,
      event.kind.name,
      event.at.toIso8601String(),
      event.alarmOn ? 'true' : 'false',
      event.notes,
      event.garmentIds.join(','),
    ];

List<List<String>>? _sheetNamed(
  Map<String, List<List<String>>> sheets,
  String wanted,
) {
  for (final entry in sheets.entries) {
    if (entry.key.trim().toLowerCase() == wanted) return entry.value;
  }
  return null;
}

List<Map<String, String>> _table(List<List<String>>? rows) {
  if (rows == null || rows.isEmpty) return const [];
  final headers = [
    for (final cell in rows.first) cell.trim().toLowerCase(),
  ];
  if (headers.every((h) => h.isEmpty)) return const [];
  final out = <Map<String, String>>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.every((cell) => cell.trim().isEmpty)) continue;
    final map = <String, String>{};
    for (var c = 0; c < headers.length; c++) {
      if (headers[c].isEmpty) continue;
      map[headers[c]] = c < row.length ? row[c].trim() : '';
    }
    out.add(map);
  }
  return out;
}

Map<String, dynamic>? _profileFromSheet(List<List<String>>? rows) {
  if (rows == null || rows.isEmpty) return null;
  final values = <String, String>{};
  for (final row in rows) {
    if (row.isEmpty) continue;
    final key = row.first.trim().toLowerCase();
    if (key.isEmpty || key == 'key') continue;
    values[key] = row.length > 1 ? row[1].trim() : '';
  }
  if (values.isEmpty) return null;
  final gender = values['gender'] ?? values['wearer'] ?? '';
  return {
    'name': values['name'] ?? '',
    'wearer': _enumName(Wearer.values, gender) ?? Wearer.woman.name,
    'dateOfBirth': values['dateofbirth'] ?? values['dob'],
    'heightCm': num.tryParse(values['heightcm'] ?? ''),
    'weightKg': num.tryParse(values['weightkg'] ?? ''),
    'description': values['description'] ?? '',
    'workdays': _ints(values['workdays'] ?? ''),
    'workStyle': _enumName(Formality.values, values['workstyle'] ?? '') ??
        Formality.smartCasual.name,
    'minRepeatDays': int.tryParse(values['minrepeatdays'] ?? '') ?? 4,
    'officeAlarmOn': _truthy(values['officealarmon'] ?? ''),
    'officeAlarmHour': int.tryParse(values['officealarmhour'] ?? '') ?? 7,
    'officeAlarmMinute': int.tryParse(values['officealarmminute'] ?? '') ?? 30,
    'customShelves': (values['customshelves'] ?? '')
        .split(RegExp(r'[|,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(),
    'onboarded': true,
  };
}

Map<String, dynamic> _garmentFromRow(Map<String, String> row) {
  final id = row['id']?.trim();
  final category = _enumName(GarmentCategory.values, row['category'] ?? '') ??
      GarmentCategory.top.name;
  final wardrobe = _enumName(
        WardrobeCategory.values,
        row['wardrobecategory'] ?? '',
      ) ??
      GarmentCategory.values.byName(category).defaultWardrobeCategory.name;
  return {
    'id': (id == null || id.isEmpty)
        ? 'excel-${DateTime.now().microsecondsSinceEpoch}-${row['name']}'
        : id,
    'name': (row['name'] ?? '').trim().isEmpty ? 'Imported item' : row['name'],
    'category': category,
    'wardrobeCategory': wardrobe,
    'topKind': _enumName(TopKind.values, row['topkind'] ?? '') ?? TopKind.top.name,
    'formality': _enumName(Formality.values, row['formality'] ?? '') ??
        Formality.smartCasual.name,
    'season': _enumName(Season.values, row['season'] ?? '') ?? Season.allSeason.name,
    'colors': _ints(row['colors'] ?? '14268856'),
    'notes': row['notes'] ?? '',
    'cost': num.tryParse(row['cost'] ?? ''),
    'favorite': _truthy(row['favorite'] ?? ''),
    'inLaundry': _truthy(row['inlaundry'] ?? ''),
    'wearCount': int.tryParse(row['wearcount'] ?? '') ?? 0,
    'createdAt': _date(row['createdat']) ?? DateTime.now().toIso8601String(),
    'lastWornAt': _date(row['lastwornat']),
    'customShelf': (row['customshelf'] ?? '').isEmpty ? null : row['customshelf'],
    'styleCollection': _enumName(
      StyleCollection.values,
      row['stylecollection'] ?? '',
    ),
    'pairsWithIds': const [],
  };
}

Map<String, dynamic> _eventFromRow(Map<String, String> row) {
  final id = row['id']?.trim();
  return {
    'id': (id == null || id.isEmpty)
        ? 'excel-event-${DateTime.now().microsecondsSinceEpoch}'
        : id,
    'title': (row['title'] ?? '').trim().isEmpty ? 'Event' : row['title'],
    'kind': _enumName(EventKind.values, row['kind'] ?? '') ?? EventKind.other.name,
    'at': _date(row['at']) ?? DateTime.now().toIso8601String(),
    'alarmOn': row.containsKey('alarmon') ? _truthy(row['alarmon']!) : true,
    'notes': row['notes'] ?? '',
    'garmentIds': (row['garmentids'] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(),
  };
}

Map<String, dynamic> _lookFromRow(Map<String, String> row) {
  final id = row['id']?.trim();
  return {
    'id': (id == null || id.isEmpty)
        ? 'excel-look-${DateTime.now().microsecondsSinceEpoch}'
        : id,
    'name': (row['name'] ?? '').trim().isEmpty ? 'Party wear' : row['name'],
    'occasion': _enumName(PartyOccasion.values, row['occasion'] ?? '') ??
        PartyOccasion.party.name,
    'createdAt': _date(row['createdat']) ?? DateTime.now().toIso8601String(),
  };
}

Map<String, dynamic> _setFromRow(Map<String, String> row) {
  final id = row['id']?.trim().isNotEmpty == true
      ? row['id']!.trim()
      : 'excel-set-${DateTime.now().microsecondsSinceEpoch}';
  return {
    'id': id,
    'name': (row['name'] ?? '').trim().isEmpty ? 'Set' : row['name'],
    'collection': _enumName(StyleCollection.values, row['collection'] ?? '') ??
        StyleCollection.officeWear.name,
    'outfit': {
      'id': id,
      'topId': _blankToNull(row['topid']),
      'bottomId': _blankToNull(row['bottomid']),
      'dressId': _blankToNull(row['dressid']),
      'outerwearId': _blankToNull(row['outerwearid']),
      'shoesId': _blankToNull(row['shoesid']),
      'accessoryId': _blankToNull(row['accessoryid']),
      'tshirtId': _blankToNull(row['tshirtid']),
    },
  };
}

Map<String, dynamic> _bucketFromRow(Map<String, String> row) {
  final id = row['id']?.trim();
  return {
    'id': (id == null || id.isEmpty)
        ? 'excel-bucket-${DateTime.now().microsecondsSinceEpoch}'
        : id,
    'title': (row['title'] ?? '').trim().isEmpty ? 'Style dream' : row['title'],
    'note': row['note'] ?? '',
    'vibe': _enumName(BucketVibe.values, row['vibe'] ?? '') ??
        BucketVibe.styleChallenge.name,
    'createdAt': _date(row['createdat']) ?? DateTime.now().toIso8601String(),
    'completedAt': _date(row['completedat']),
    'starred': _truthy(row['starred'] ?? ''),
  };
}

Map<String, dynamic> _dayFromRow(Map<String, String> row) {
  final date = _date(row['date']) ?? DateTime.now().toIso8601String();
  return {
    'date': date,
    'locked': _truthy(row['locked'] ?? ''),
    'worn': _truthy(row['worn'] ?? ''),
    'outfit': {
      'id': 'day-$date',
      'topId': _blankToNull(row['topid']),
      'bottomId': _blankToNull(row['bottomid']),
      'dressId': _blankToNull(row['dressid']),
      'outerwearId': _blankToNull(row['outerwearid']),
      'shoesId': _blankToNull(row['shoesid']),
      'accessoryId': _blankToNull(row['accessoryid']),
      'tshirtId': _blankToNull(row['tshirtid']),
    },
  };
}

String? _blankToNull(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

List<int> _ints(String raw) {
  return [
    for (final part in raw.split(RegExp(r'[|,]')))
      if (int.tryParse(part.trim()) != null) int.parse(part.trim()),
  ];
}

bool _truthy(String raw) {
  final value = raw.trim().toLowerCase();
  return value == 'true' || value == '1' || value == 'yes' || value == 'on';
}

String? _date(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toIso8601String();
}

String? _enumName<T extends Enum>(List<T> values, String raw) {
  final key = raw.trim();
  if (key.isEmpty) return null;
  for (final value in values) {
    if (value.name.toLowerCase() == key.toLowerCase()) return value.name;
  }
  for (final value in values) {
    final label = switch (value) {
      Wearer v => v.genderLabel,
      GarmentCategory v => v.label,
      WardrobeCategory v => v.label,
      Formality v => v.label,
      Season v => v.label,
      EventKind v => v.label,
      PartyOccasion v => v.label,
      BucketVibe v => v.label,
      StyleCollection v => v.label,
      TopKind v => v.label,
      _ => value.name,
    };
    if (label.toLowerCase() == key.toLowerCase()) return value.name;
  }
  return null;
}
