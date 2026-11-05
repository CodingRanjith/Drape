/// Cute animated stickers you can hang in wardrobe shelf rows.
class WardrobeDecorKind {
  const WardrobeDecorKind({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;
}

/// At least 10 gif-style wardrobe decorations.
const wardrobeDecorCatalog = <WardrobeDecorKind>[
  WardrobeDecorKind(id: 'teddy', label: 'Teddy', emoji: '🧸'),
  WardrobeDecorKind(id: 'fishtank', label: 'Fish tank', emoji: '🐠'),
  WardrobeDecorKind(id: 'plant', label: 'Plant', emoji: '🪴'),
  WardrobeDecorKind(id: 'kitten', label: 'Kitten', emoji: '🐱'),
  WardrobeDecorKind(id: 'lamp', label: 'Lamp', emoji: '💡'),
  WardrobeDecorKind(id: 'clock', label: 'Clock', emoji: '🕰️'),
  WardrobeDecorKind(id: 'fairy', label: 'Fairy lights', emoji: '✨'),
  WardrobeDecorKind(id: 'perfume', label: 'Perfume', emoji: '🧴'),
  WardrobeDecorKind(id: 'butterfly', label: 'Butterfly', emoji: '🦋'),
  WardrobeDecorKind(id: 'pillow', label: 'Heart pillow', emoji: '💗'),
  WardrobeDecorKind(id: 'duck', label: 'Duck', emoji: '🦆'),
  WardrobeDecorKind(id: 'stars', label: 'Star mobile', emoji: '🌟'),
];

WardrobeDecorKind? decorKindById(String id) {
  for (final k in wardrobeDecorCatalog) {
    if (k.id == id) return k;
  }
  return null;
}

class WardrobeDecorPlacement {
  const WardrobeDecorPlacement({
    required this.id,
    required this.decorId,
    required this.shelfLabel,
  });

  final String id;
  final String decorId;
  final String shelfLabel;

  WardrobeDecorKind? get kind => decorKindById(decorId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'decorId': decorId,
        'shelfLabel': shelfLabel,
      };

  factory WardrobeDecorPlacement.fromJson(Map<String, dynamic> json) {
    return WardrobeDecorPlacement(
      id: json['id'] as String,
      decorId: json['decorId'] as String,
      shelfLabel: json['shelfLabel'] as String,
    );
  }
}
