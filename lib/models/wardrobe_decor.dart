/// Cute animated stickers you can hang in wardrobe shelf rows.
class WardrobeDecorKind {
  const WardrobeDecorKind({
    required this.id,
    required this.label,
    required this.emoji,
    required this.tags,
    required this.gifUrl,
  });

  final String id;
  final String label;
  final String emoji;
  final List<String> tags;

  /// Animated GIF with a real background (not a flat emoji).
  final String gifUrl;

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (label.toLowerCase().contains(q)) return true;
    if (id.toLowerCase().contains(q)) return true;
    for (final tag in tags) {
      if (tag.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

/// Curated animated GIFs (with backgrounds) for wardrobe customize.
const wardrobeDecorCatalog = <WardrobeDecorKind>[
  WardrobeDecorKind(
    id: 'teddy',
    label: 'Teddy',
    emoji: '🧸',
    tags: ['teddy', 'bear', 'cute', 'toy', 'soft'],
    gifUrl: 'https://media.giphy.com/media/l0MYC0LrdPWZBsyU0/200.gif',
  ),
  WardrobeDecorKind(
    id: 'fishtank',
    label: 'Fish tank',
    emoji: '🐠',
    tags: ['fish', 'tank', 'water', 'aquarium', 'ocean'],
    gifUrl: 'https://media.giphy.com/media/3o7TKP9z2ytbmH2k3e/200.gif',
  ),
  WardrobeDecorKind(
    id: 'plant',
    label: 'Plant',
    emoji: '🪴',
    tags: ['plant', 'leaf', 'green', 'nature', 'pot'],
    gifUrl: 'https://media.giphy.com/media/l0HlNQ03J5JxX6lva/200.gif',
  ),
  WardrobeDecorKind(
    id: 'kitten',
    label: 'Kitten',
    emoji: '🐱',
    tags: ['cat', 'kitten', 'pet', 'cute', 'meow'],
    gifUrl: 'https://media.giphy.com/media/JIX9t2j0ZTN9S/200.gif',
  ),
  WardrobeDecorKind(
    id: 'lamp',
    label: 'Lamp',
    emoji: '💡',
    tags: ['lamp', 'light', 'glow', 'room'],
    gifUrl: 'https://media.giphy.com/media/3o6Zt481isNVuQI1l6/200.gif',
  ),
  WardrobeDecorKind(
    id: 'clock',
    label: 'Clock',
    emoji: '🕰️',
    tags: ['clock', 'time', 'tick', 'watch'],
    gifUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/200.gif',
  ),
  WardrobeDecorKind(
    id: 'fairy',
    label: 'Fairy lights',
    emoji: '✨',
    tags: ['fairy', 'lights', 'sparkle', 'glow', 'stars'],
    gifUrl: 'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/200.gif',
  ),
  WardrobeDecorKind(
    id: 'perfume',
    label: 'Perfume',
    emoji: '🧴',
    tags: ['perfume', 'beauty', 'scent', 'bottle'],
    gifUrl: 'https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/200.gif',
  ),
  WardrobeDecorKind(
    id: 'butterfly',
    label: 'Butterfly',
    emoji: '🦋',
    tags: ['butterfly', 'fly', 'pretty', 'nature'],
    gifUrl: 'https://media.giphy.com/media/3oEduQAsYcJKQH2XsI/200.gif',
  ),
  WardrobeDecorKind(
    id: 'pillow',
    label: 'Heart pillow',
    emoji: '💗',
    tags: ['heart', 'pillow', 'love', 'soft', 'cute'],
    gifUrl: 'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/200.gif',
  ),
  WardrobeDecorKind(
    id: 'duck',
    label: 'Duck',
    emoji: '🦆',
    tags: ['duck', 'bird', 'cute', 'yellow'],
    gifUrl: 'https://media.giphy.com/media/l0HlvtIPzPdt2usKs/200.gif',
  ),
  WardrobeDecorKind(
    id: 'stars',
    label: 'Star mobile',
    emoji: '🌟',
    tags: ['star', 'mobile', 'night', 'sparkle'],
    gifUrl: 'https://media.giphy.com/media/3o7TKSjRrfIPjeiVyM/200.gif',
  ),
  WardrobeDecorKind(
    id: 'coffee',
    label: 'Coffee',
    emoji: '☕',
    tags: ['coffee', 'mug', 'warm', 'morning'],
    gifUrl: 'https://media.giphy.com/media/3o6Zt6ML6BklcajjsA/200.gif',
  ),
  WardrobeDecorKind(
    id: 'rainbow',
    label: 'Rainbow',
    emoji: '🌈',
    tags: ['rainbow', 'color', 'sky', 'bright'],
    gifUrl: 'https://media.giphy.com/media/26BRv0ThapV5ARqBU/200.gif',
  ),
  WardrobeDecorKind(
    id: 'dog',
    label: 'Puppy',
    emoji: '🐶',
    tags: ['dog', 'puppy', 'pet', 'cute'],
    gifUrl: 'https://media.giphy.com/media/4Zo41lhzKt6iZ8xff9/200.gif',
  ),
  WardrobeDecorKind(
    id: 'books',
    label: 'Books',
    emoji: '📚',
    tags: ['book', 'read', 'shelf', 'study'],
    gifUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/200.gif',
  ),
];

WardrobeDecorKind? decorKindById(String id) {
  for (final k in wardrobeDecorCatalog) {
    if (k.id == id) return k;
  }
  return null;
}

List<WardrobeDecorKind> searchWardrobeDecor(String query) {
  return [
    for (final kind in wardrobeDecorCatalog)
      if (kind.matchesQuery(query)) kind,
  ];
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
