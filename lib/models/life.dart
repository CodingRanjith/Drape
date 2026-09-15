enum EventKind { birthday, function, party, other }

enum PartyOccasion { party, function, wedding, festival }

extension EventKindX on EventKind {
  String get label => switch (this) {
    EventKind.birthday => 'Birthday',
    EventKind.function => 'Function',
    EventKind.party => 'Party',
    EventKind.other => 'Other',
  };
}

extension PartyOccasionX on PartyOccasion {
  String get label => switch (this) {
    PartyOccasion.party => 'Party wear',
    PartyOccasion.function => 'Function',
    PartyOccasion.wedding => 'Wedding',
    PartyOccasion.festival => 'Festival',
  };
}

class LifeEvent {
  LifeEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.at,
    this.alarmOn = true,
    this.musicPath,
    this.musicName,
    this.partyLookId,
    this.notes = '',
    this.alarmFired = false,
    List<String>? garmentIds,
  }) : garmentIds = garmentIds ?? [];

  final String id;
  String title;
  EventKind kind;
  DateTime at;
  bool alarmOn;
  String? musicPath;
  String? musicName;
  String? partyLookId;
  List<String> garmentIds;
  String notes;
  bool alarmFired;

  int get alarmId => id.hashCode & 0x7fffffff;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'at': at.toIso8601String(),
    'alarmOn': alarmOn,
    'musicPath': musicPath,
    'musicName': musicName,
    'partyLookId': partyLookId,
    'garmentIds': garmentIds,
    'notes': notes,
    'alarmFired': alarmFired,
  };

  factory LifeEvent.fromJson(Map<String, dynamic> json) => LifeEvent(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Event',
    kind: EventKind.values.byName(json['kind'] as String? ?? EventKind.other.name),
    at: DateTime.parse(json['at'] as String),
    alarmOn: json['alarmOn'] as bool? ?? true,
    musicPath: json['musicPath'] as String?,
    musicName: json['musicName'] as String?,
    partyLookId: json['partyLookId'] as String?,
    garmentIds: ((json['garmentIds'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
    notes: json['notes'] as String? ?? '',
    alarmFired: json['alarmFired'] as bool? ?? false,
  );
}

class PartyLook {
  PartyLook({
    required this.id,
    required this.name,
    required this.occasion,
    this.imagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  PartyOccasion occasion;
  String? imagePath;
  DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'occasion': occasion.name,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PartyLook.fromJson(Map<String, dynamic> json) => PartyLook(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Party wear',
    occasion: PartyOccasion.values.byName(
      json['occasion'] as String? ?? PartyOccasion.party.name,
    ),
    imagePath: json['imagePath'] as String?,
    createdAt: json['createdAt'] == null
        ? DateTime.now()
        : DateTime.parse(json['createdAt'] as String),
  );
}
