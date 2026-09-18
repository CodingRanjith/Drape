import 'package:flutter/material.dart';

enum GarmentCategory { top, bottom, dress, outerwear, shoes, accessory }

/// Fine-grained wardrobe shelves shown on My Wardrobe (cupboard UI).
enum WardrobeCategory {
  topwear,
  tshirts,
  shirts,
  bottomwear,
  jeans,
  trousers,
  shorts,
  skirts,
  dresses,
  ethnicWear,
  sarees,
  outerwear,
  sweaters,
  activewear,
  sleepwear,
  footwear,
  sandals,
  innerwear,
  socks,
  accessories,
  jewellery,
  bags,
  belts,
  scarves,
  caps,
}

enum Formality { casual, smartCasual, formal }

enum Season { allSeason, summer, monsoon, winter }

enum ClosetFilter { all, clean, laundry, favorites, neglected }

enum Wearer { woman, man }

enum TopKind { top, shirt, tshirt }

class ClothesType {
  const ClothesType(this.category, {this.topKind = TopKind.top});

  final GarmentCategory category;
  final TopKind topKind;

  String get label {
    if (category == GarmentCategory.top) return topKind.label;
    return category.label;
  }

  static String slotLabel(GarmentCategory category, Wearer wearer) {
    if (wearer == Wearer.man && category == GarmentCategory.top) {
      return 'Shirt / T-shirt';
    }
    return category.label;
  }

  static List<ClothesType> todaySlots(Wearer wearer) {
    if (wearer == Wearer.man) {
      return const [
        ClothesType(GarmentCategory.top, topKind: TopKind.shirt),
        ClothesType(GarmentCategory.top, topKind: TopKind.tshirt),
        ClothesType(GarmentCategory.bottom),
      ];
    }
    return const [
      ClothesType(GarmentCategory.top),
      ClothesType(GarmentCategory.dress),
      ClothesType(GarmentCategory.bottom),
      ClothesType(GarmentCategory.outerwear),
    ];
  }

  bool matches(Garment garment) {
    if (garment.category != category) return false;
    if (category == GarmentCategory.top) return garment.topKind == topKind;
    return true;
  }

  static List<ClothesType> forWearer(Wearer wearer) {
    if (wearer == Wearer.man) {
      return const [
        ClothesType(GarmentCategory.top, topKind: TopKind.shirt),
        ClothesType(GarmentCategory.top, topKind: TopKind.tshirt),
        ClothesType(GarmentCategory.bottom),
      ];
    }
    return const [
      ClothesType(GarmentCategory.top),
      ClothesType(GarmentCategory.bottom),
      ClothesType(GarmentCategory.outerwear),
      ClothesType(GarmentCategory.shoes),
      ClothesType(GarmentCategory.accessory),
      ClothesType(GarmentCategory.dress),
    ];
  }
}

extension WearerX on Wearer {
  String get label => this == Wearer.woman ? 'Women' : 'Men';
  String get genderLabel => this == Wearer.woman ? 'Female' : 'Male';
  String get portraitAsset =>
      this == Wearer.woman ? 'assets/gender_female.png' : 'assets/gender_male.png';

  /// Cupboard categories for this gender (~20 each).
  List<WardrobeCategory> get wardrobeCategories =>
      WardrobeCategoryX.forWearer(this);

  /// Search-field examples that match this gender's shelves.
  String get categorySearchHint => this == Wearer.man
      ? 'Search shirts, jeans, footwear…'
      : 'Search tops, saree, jewellery…';
}

extension TopKindX on TopKind {
  String get label => switch (this) {
    TopKind.top => 'Top',
    TopKind.shirt => 'Shirt',
    TopKind.tshirt => 'T-shirt',
  };
}

extension GarmentCategoryX on GarmentCategory {
  String get label => switch (this) {
    GarmentCategory.top => 'Top',
    GarmentCategory.bottom => 'Pant',
    GarmentCategory.dress => 'Dress',
    GarmentCategory.outerwear => 'Shawl',
    GarmentCategory.shoes => 'Slippers',
    GarmentCategory.accessory => 'Earrings',
  };

  String get sectionTitle => switch (this) {
    GarmentCategory.top => 'Tops',
    GarmentCategory.bottom => 'Pants',
    GarmentCategory.dress => 'Dresses',
    GarmentCategory.outerwear => 'Shawls',
    GarmentCategory.shoes => 'Slippers',
    GarmentCategory.accessory => 'Earrings',
  };

  IconData get icon => switch (this) {
    GarmentCategory.top => Icons.checkroom_outlined,
    GarmentCategory.bottom => Icons.straighten,
    GarmentCategory.dress => Icons.dry_cleaning_outlined,
    GarmentCategory.outerwear => Icons.layers_outlined,
    GarmentCategory.shoes => Icons.ice_skating_outlined,
    GarmentCategory.accessory => Icons.diamond_outlined,
  };

  WardrobeCategory get defaultWardrobeCategory => switch (this) {
    GarmentCategory.top => WardrobeCategory.topwear,
    GarmentCategory.bottom => WardrobeCategory.bottomwear,
    GarmentCategory.dress => WardrobeCategory.dresses,
    GarmentCategory.outerwear => WardrobeCategory.outerwear,
    GarmentCategory.shoes => WardrobeCategory.footwear,
    GarmentCategory.accessory => WardrobeCategory.accessories,
  };
}

extension WardrobeCategoryX on WardrobeCategory {
  String get label => switch (this) {
    WardrobeCategory.topwear => 'Topwear',
    WardrobeCategory.tshirts => 'T-shirts',
    WardrobeCategory.shirts => 'Shirts',
    WardrobeCategory.bottomwear => 'Bottomwear',
    WardrobeCategory.jeans => 'Jeans',
    WardrobeCategory.trousers => 'Trousers',
    WardrobeCategory.shorts => 'Shorts',
    WardrobeCategory.skirts => 'Skirts',
    WardrobeCategory.dresses => 'Dresses',
    WardrobeCategory.ethnicWear => 'Ethnic wear',
    WardrobeCategory.sarees => 'Sarees',
    WardrobeCategory.outerwear => 'Outerwear',
    WardrobeCategory.sweaters => 'Sweaters',
    WardrobeCategory.activewear => 'Activewear',
    WardrobeCategory.sleepwear => 'Sleepwear',
    WardrobeCategory.footwear => 'Footwear',
    WardrobeCategory.sandals => 'Sandals',
    WardrobeCategory.innerwear => 'Innerwear',
    WardrobeCategory.socks => 'Socks',
    WardrobeCategory.accessories => 'Accessories',
    WardrobeCategory.jewellery => 'Jewellery',
    WardrobeCategory.bags => 'Bags',
    WardrobeCategory.belts => 'Belts',
    WardrobeCategory.scarves => 'Scarves',
    WardrobeCategory.caps => 'Caps & hats',
  };

  IconData get icon => switch (this) {
    WardrobeCategory.topwear => Icons.checkroom_outlined,
    WardrobeCategory.tshirts => Icons.dry_cleaning_outlined,
    WardrobeCategory.shirts => Icons.checkroom,
    WardrobeCategory.bottomwear => Icons.straighten,
    WardrobeCategory.jeans => Icons.accessibility_new_outlined,
    WardrobeCategory.trousers => Icons.view_day_outlined,
    WardrobeCategory.shorts => Icons.crop_16_9_outlined,
    WardrobeCategory.skirts => Icons.woman_outlined,
    WardrobeCategory.dresses => Icons.dry_cleaning,
    WardrobeCategory.ethnicWear => Icons.spa_outlined,
    WardrobeCategory.sarees => Icons.auto_awesome_outlined,
    WardrobeCategory.outerwear => Icons.layers_outlined,
    WardrobeCategory.sweaters => Icons.ac_unit_outlined,
    WardrobeCategory.activewear => Icons.fitness_center_outlined,
    WardrobeCategory.sleepwear => Icons.bedtime_outlined,
    WardrobeCategory.footwear => Icons.ice_skating_outlined,
    WardrobeCategory.sandals => Icons.beach_access_outlined,
    WardrobeCategory.innerwear => Icons.loyalty_outlined,
    WardrobeCategory.socks => Icons.texture_outlined,
    WardrobeCategory.accessories => Icons.watch_outlined,
    WardrobeCategory.jewellery => Icons.diamond_outlined,
    WardrobeCategory.bags => Icons.shopping_bag_outlined,
    WardrobeCategory.belts => Icons.horizontal_rule,
    WardrobeCategory.scarves => Icons.air_outlined,
    WardrobeCategory.caps => Icons.sports_baseball_outlined,
  };

  /// Cupboard categories for this gender only (~20).
  static List<WardrobeCategory> forWearer(Wearer wearer) {
    return List<WardrobeCategory>.from(
      wearer == Wearer.man ? _menCategories : _womenCategories,
    );
  }

  static const List<WardrobeCategory> _womenCategories = [
    WardrobeCategory.topwear,
    WardrobeCategory.tshirts,
    WardrobeCategory.shirts,
    WardrobeCategory.bottomwear,
    WardrobeCategory.jeans,
    WardrobeCategory.trousers,
    WardrobeCategory.skirts,
    WardrobeCategory.dresses,
    WardrobeCategory.ethnicWear,
    WardrobeCategory.sarees,
    WardrobeCategory.outerwear,
    WardrobeCategory.sweaters,
    WardrobeCategory.activewear,
    WardrobeCategory.sleepwear,
    WardrobeCategory.footwear,
    WardrobeCategory.sandals,
    WardrobeCategory.innerwear,
    WardrobeCategory.accessories,
    WardrobeCategory.jewellery,
    WardrobeCategory.bags,
  ];

  static const List<WardrobeCategory> _menCategories = [
    WardrobeCategory.topwear,
    WardrobeCategory.tshirts,
    WardrobeCategory.shirts,
    WardrobeCategory.bottomwear,
    WardrobeCategory.jeans,
    WardrobeCategory.trousers,
    WardrobeCategory.shorts,
    WardrobeCategory.ethnicWear,
    WardrobeCategory.outerwear,
    WardrobeCategory.sweaters,
    WardrobeCategory.activewear,
    WardrobeCategory.sleepwear,
    WardrobeCategory.footwear,
    WardrobeCategory.sandals,
    WardrobeCategory.innerwear,
    WardrobeCategory.socks,
    WardrobeCategory.accessories,
    WardrobeCategory.bags,
    WardrobeCategory.belts,
    WardrobeCategory.caps,
  ];

  bool isForWearer(Wearer wearer) => forWearer(wearer).contains(this);

  /// Maps cupboard shelf types onto outfit planning slots.
  GarmentCategory get garmentCategory => switch (this) {
    WardrobeCategory.topwear ||
    WardrobeCategory.tshirts ||
    WardrobeCategory.shirts ||
    WardrobeCategory.sweaters ||
    WardrobeCategory.activewear ||
    WardrobeCategory.sleepwear ||
    WardrobeCategory.innerwear =>
      GarmentCategory.top,
    WardrobeCategory.bottomwear ||
    WardrobeCategory.jeans ||
    WardrobeCategory.trousers ||
    WardrobeCategory.shorts ||
    WardrobeCategory.skirts ||
    WardrobeCategory.socks =>
      GarmentCategory.bottom,
    WardrobeCategory.dresses ||
    WardrobeCategory.ethnicWear ||
    WardrobeCategory.sarees =>
      GarmentCategory.dress,
    WardrobeCategory.outerwear || WardrobeCategory.scarves =>
      GarmentCategory.outerwear,
    WardrobeCategory.footwear || WardrobeCategory.sandals =>
      GarmentCategory.shoes,
    WardrobeCategory.accessories ||
    WardrobeCategory.jewellery ||
    WardrobeCategory.bags ||
    WardrobeCategory.belts ||
    WardrobeCategory.caps =>
      GarmentCategory.accessory,
  };

  TopKind get topKind => switch (this) {
    WardrobeCategory.shirts => TopKind.shirt,
    WardrobeCategory.tshirts => TopKind.tshirt,
    _ => TopKind.top,
  };
}

extension FormalityX on Formality {
  String get label => switch (this) {
    Formality.casual => 'Casual',
    Formality.smartCasual => 'Smart casual',
    Formality.formal => 'Formal',
  };
}

extension SeasonX on Season {
  String get label => switch (this) {
    Season.allSeason => 'All year',
    Season.summer => 'Summer',
    Season.monsoon => 'Rainy season',
    Season.winter => 'Winter',
  };
}

class PaletteColor {
  const PaletteColor(this.name, this.value);
  final String name;
  final Color value;
}

const fashionPalette = <PaletteColor>[
  PaletteColor('Black', Color(0xFF1A1A1A)),
  PaletteColor('White', Color(0xFFF5F5F0)),
  PaletteColor('Ivory', Color(0xFFF3E6D4)),
  PaletteColor('Beige', Color(0xFFD4C4A8)),
  PaletteColor('Grey', Color(0xFF8A8A8A)),
  PaletteColor('Charcoal', Color(0xFF4A4A4A)),
  PaletteColor('Navy', Color(0xFF1F3358)),
  PaletteColor('Blue', Color(0xFF3D6EA8)),
  PaletteColor('Sky', Color(0xFF8BB4D4)),
  PaletteColor('Olive', Color(0xFF6B7A4A)),
  PaletteColor('Forest', Color(0xFF2F5D46)),
  PaletteColor('Green', Color(0xFF3F8F5A)),
  PaletteColor('Brown', Color(0xFF6B4A32)),
  PaletteColor('Camel', Color(0xFFC4A06A)),
  PaletteColor('Gold', Color(0xFFB0894F)),
  PaletteColor('Terracotta', Color(0xFFC45C26)),
  PaletteColor('Red', Color(0xFFB42318)),
  PaletteColor('Maroon', Color(0xFF7A2E2E)),
  PaletteColor('Wine', Color(0xFF6B2748)),
  PaletteColor('Pink', Color(0xFFE8A0B0)),
  PaletteColor('Purple', Color(0xFF6B4C9A)),
  PaletteColor('Mustard', Color(0xFFD4A017)),
  PaletteColor('Yellow', Color(0xFFE6C84A)),
];

int colorArgb(Color color) => color.toARGB32();

Color colorFromArgb(int value) {
  var v = value;
  if (v >= 0 && v <= 0xFFFFFF) v = 0xFF000000 | v;
  return Color(v);
}

String colorNameOf(Color color) {
  final argb = colorArgb(color);
  for (final swatch in fashionPalette) {
    if (colorArgb(swatch.value) == argb) return swatch.name;
  }
  return 'Custom';
}

bool colorsMatch(int stored, Color color) => stored == colorArgb(color);

class Garment {
  Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.colors,
    this.formality = Formality.smartCasual,
    this.season = Season.allSeason,
    this.imagePath,
    DateTime? createdAt,
    this.lastWornAt,
    this.wearCount = 0,
    this.inLaundry = false,
    this.favorite = false,
    this.notes = '',
    List<String>? pairsWithIds,
    this.topKind = TopKind.top,
    this.styleCollection,
    WardrobeCategory? wardrobeCategory,
    this.customShelf,
    this.cost,
  }) : createdAt = createdAt ?? DateTime.now(),
       pairsWithIds = pairsWithIds ?? [],
       wardrobeCategory =
           wardrobeCategory ?? category.defaultWardrobeCategory;

  final String id;
  String name;
  GarmentCategory category;
  List<int> colors;
  Formality formality;
  Season season;
  String? imagePath;
  DateTime createdAt;
  DateTime? lastWornAt;
  int wearCount;
  bool inLaundry;
  bool favorite;
  String notes;
  List<String> pairsWithIds;
  TopKind topKind;
  /// When set, this piece is a single item under that collection card.
  StyleCollection? styleCollection;
  WardrobeCategory wardrobeCategory;
  /// User-created shelf name (dynamic category). When set, cupboard groups by this.
  String? customShelf;
  /// Optional purchase / item cost.
  double? cost;

  String get shelfLabel {
    final custom = customShelf?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return wardrobeCategory.label;
  }

  String get typeLabel {
    final custom = customShelf?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    if (wardrobeCategory != category.defaultWardrobeCategory) {
      return wardrobeCategory.label;
    }
    if (category == GarmentCategory.top) return topKind.label;
    return category.label;
  }

  Color get primaryColor =>
      colors.isEmpty ? const Color(0xFFD9C7B8) : colorFromArgb(colors.first);

  int daysSinceWorn([DateTime? now]) {
    final at = lastWornAt;
    if (at == null) return 999;
    return (now ?? DateTime.now()).difference(at).inDays;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'colors': colors,
    'formality': formality.name,
    'season': season.name,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'lastWornAt': lastWornAt?.toIso8601String(),
    'wearCount': wearCount,
    'inLaundry': inLaundry,
    'favorite': favorite,
    'notes': notes,
    'pairsWithIds': pairsWithIds,
    'topKind': topKind.name,
    'styleCollection': styleCollection?.name,
    'wardrobeCategory': wardrobeCategory.name,
    'customShelf': customShelf,
    'cost': cost,
  };

  factory Garment.fromJson(Map<String, dynamic> json) {
    final category = GarmentCategory.values.byName(json['category'] as String);
    return Garment(
      id: json['id'] as String,
      name: json['name'] as String,
      category: category,
      colors: (json['colors'] as List).map((e) => (e as num).toInt()).toList(),
      formality: Formality.values.byName(json['formality'] as String),
      season: Season.values.byName(json['season'] as String),
      imagePath: json['imagePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastWornAt: json['lastWornAt'] == null
          ? null
          : DateTime.parse(json['lastWornAt'] as String),
      wearCount: json['wearCount'] as int? ?? 0,
      inLaundry: json['inLaundry'] as bool? ?? false,
      favorite: json['favorite'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      pairsWithIds: ((json['pairsWithIds'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      topKind: TopKind.values.byName(json['topKind'] as String? ?? TopKind.top.name),
      styleCollection: json['styleCollection'] == null
          ? null
          : StyleCollection.values.byName(json['styleCollection'] as String),
      wardrobeCategory: json['wardrobeCategory'] == null
          ? category.defaultWardrobeCategory
          : WardrobeCategory.values.byName(json['wardrobeCategory'] as String),
      customShelf: json['customShelf'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
    );
  }
}

class Outfit {
  Outfit({
    required this.id,
    this.topId,
    this.bottomId,
    this.dressId,
    this.outerwearId,
    this.shoesId,
    this.accessoryId,
    this.tshirtId,
  });

  final String id;
  String? topId;
  String? bottomId;
  String? dressId;
  String? outerwearId;
  String? shoesId;
  String? accessoryId;
  String? tshirtId;

  bool get isEmpty => pieceIds.isEmpty;

  List<String> get pieceIds => [
    ?topId,
    ?bottomId,
    ?dressId,
    ?outerwearId,
    ?shoesId,
    ?accessoryId,
    ?tshirtId,
  ];

  String? idFor(GarmentCategory category) => switch (category) {
    GarmentCategory.top => topId,
    GarmentCategory.bottom => bottomId,
    GarmentCategory.dress => dressId,
    GarmentCategory.outerwear => outerwearId,
    GarmentCategory.shoes => shoesId,
    GarmentCategory.accessory => accessoryId,
  };

  String? idForType(ClothesType type) {
    if (type.topKind == TopKind.tshirt) return tshirtId;
    return idFor(type.category);
  }

  void setIdFor(GarmentCategory category, String? id) {
    switch (category) {
      case GarmentCategory.top:
        topId = id;
      case GarmentCategory.bottom:
        bottomId = id;
      case GarmentCategory.dress:
        dressId = id;
      case GarmentCategory.outerwear:
        outerwearId = id;
      case GarmentCategory.shoes:
        shoesId = id;
      case GarmentCategory.accessory:
        accessoryId = id;
    }
  }

  void setIdForType(ClothesType type, String? id) {
    if (type.topKind == TopKind.tshirt) {
      tshirtId = id;
      return;
    }
    setIdFor(type.category, id);
  }

  Outfit copy({String? id}) => Outfit(
    id: id ?? this.id,
    topId: topId,
    bottomId: bottomId,
    dressId: dressId,
    outerwearId: outerwearId,
    shoesId: shoesId,
    accessoryId: accessoryId,
    tshirtId: tshirtId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'topId': topId,
    'bottomId': bottomId,
    'dressId': dressId,
    'outerwearId': outerwearId,
    'shoesId': shoesId,
    'accessoryId': accessoryId,
    'tshirtId': tshirtId,
  };

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
    id: json['id'] as String,
    topId: json['topId'] as String?,
    bottomId: json['bottomId'] as String?,
    dressId: json['dressId'] as String?,
    outerwearId: json['outerwearId'] as String?,
    shoesId: json['shoesId'] as String?,
    accessoryId: json['accessoryId'] as String?,
    tshirtId: json['tshirtId'] as String?,
  );
}

enum StyleCollection {
  officeWear,
  nightDress,
  partyWear,
  marriageFunctions,
  outing,
  western,
  traditional,
  casual,
  festival,
  travel,
}

extension StyleCollectionX on StyleCollection {
  String get label => switch (this) {
    StyleCollection.officeWear => 'Office wear',
    StyleCollection.nightDress => 'Night dress',
    StyleCollection.partyWear => 'Party wear',
    StyleCollection.marriageFunctions => 'Marriage and functions',
    StyleCollection.outing => 'Outing',
    StyleCollection.western => 'Western',
    StyleCollection.traditional => 'Traditional',
    StyleCollection.casual => 'Casual',
    StyleCollection.festival => 'Festival',
    StyleCollection.travel => 'Travel',
  };

  String get subtitle => switch (this) {
    StyleCollection.officeWear => 'Add office singles or full sets',
    StyleCollection.nightDress => 'Soft night looks — add when ready',
    StyleCollection.partyWear => 'Looks for parties',
    StyleCollection.marriageFunctions => 'Wedding and function looks',
    StyleCollection.outing => 'Casual outing looks',
    StyleCollection.western => 'Western wear looks',
    StyleCollection.traditional => 'Ethnic and traditional looks',
    StyleCollection.casual => 'Everyday easy looks',
    StyleCollection.festival => 'Festival and celebration looks',
    StyleCollection.travel => 'Trip-ready outfits',
  };

  String get coverAsset => coverAssetFor(Wearer.woman);

  String coverAssetFor(Wearer wearer) {
    if (wearer == Wearer.man) {
      return switch (this) {
        StyleCollection.officeWear => 'assets/gender_male.png',
        StyleCollection.nightDress => 'assets/men1.webp',
        StyleCollection.partyWear => 'assets/men1.webp',
        StyleCollection.marriageFunctions => 'assets/gender_male.png',
        StyleCollection.outing => 'assets/men1.webp',
        StyleCollection.western => 'assets/gender_male.png',
        StyleCollection.traditional => 'assets/gender_male.png',
        StyleCollection.casual => 'assets/men1.webp',
        StyleCollection.festival => 'assets/gender_male.png',
        StyleCollection.travel => 'assets/men1.webp',
      };
    }
    return switch (this) {
      StyleCollection.officeWear => 'assets/gender_female.png',
      StyleCollection.nightDress => 'assets/walkthrough/week.png',
      StyleCollection.partyWear => 'assets/girl1.jpg',
      StyleCollection.marriageFunctions => 'assets/walkthrough/today.png',
      StyleCollection.outing => 'assets/walkthrough/closet.png',
      StyleCollection.western => 'assets/girl1.jpg',
      StyleCollection.traditional => 'assets/gender_female.png',
      StyleCollection.casual => 'assets/walkthrough/closet.png',
      StyleCollection.festival => 'assets/girl1.jpg',
      StyleCollection.travel => 'assets/walkthrough/today.png',
    };
  }

  List<Color> get coverGradient => switch (this) {
    StyleCollection.officeWear => const [Color(0xFF3F5E51), Color(0xFF1C1612)],
    StyleCollection.nightDress => const [Color(0xFF2A2438), Color(0xFF1C1612)],
    StyleCollection.partyWear => const [Color(0xFF6B2748), Color(0xFF1C1612)],
    StyleCollection.marriageFunctions => const [
      Color(0xFFB0894F),
      Color(0xFF1C1612),
    ],
    StyleCollection.outing => const [Color(0xFF3D6EA8), Color(0xFF1C1612)],
    StyleCollection.western => const [Color(0xFFC45C26), Color(0xFF1C1612)],
    StyleCollection.traditional => const [Color(0xFF8B3A3A), Color(0xFF1C1612)],
    StyleCollection.casual => const [Color(0xFF5A6B4F), Color(0xFF1C1612)],
    StyleCollection.festival => const [Color(0xFF9B4D1B), Color(0xFF1C1612)],
    StyleCollection.travel => const [Color(0xFF2F5D7C), Color(0xFF1C1612)],
  };

  IconData get icon => switch (this) {
    StyleCollection.officeWear => Icons.work_outline_rounded,
    StyleCollection.nightDress => Icons.nightlight_round,
    StyleCollection.partyWear => Icons.celebration_outlined,
    StyleCollection.marriageFunctions => Icons.favorite_border_rounded,
    StyleCollection.outing => Icons.park_outlined,
    StyleCollection.western => Icons.dry_cleaning_outlined,
    StyleCollection.traditional => Icons.spa_outlined,
    StyleCollection.casual => Icons.weekend_outlined,
    StyleCollection.festival => Icons.auto_awesome_outlined,
    StyleCollection.travel => Icons.flight_takeoff_rounded,
  };
}

class ClothSet {
  ClothSet({
    required this.id,
    required this.name,
    required this.collection,
    Outfit? outfit,
  }) : outfit = outfit ?? Outfit(id: id);

  final String id;
  String name;
  StyleCollection collection;
  Outfit outfit;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'collection': collection.name,
    'outfit': outfit.toJson(),
  };

  factory ClothSet.fromJson(Map<String, dynamic> json) => ClothSet(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Set',
    collection: StyleCollection.values.byName(
      json['collection'] as String? ?? StyleCollection.officeWear.name,
    ),
    outfit: json['outfit'] == null
        ? Outfit(id: json['id'] as String)
        : Outfit.fromJson(json['outfit'] as Map<String, dynamic>),
  );
}

class DayPlan {
  DayPlan({
    required this.date,
    this.outfit,
    this.locked = false,
    this.worn = false,
  });

  DateTime date;
  Outfit? outfit;
  bool locked;
  bool worn;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'outfit': outfit?.toJson(),
    'locked': locked,
    'worn': worn,
  };

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
    date: DateTime.parse(json['date'] as String),
    outfit: json['outfit'] == null
        ? null
        : Outfit.fromJson(json['outfit'] as Map<String, dynamic>),
    locked: json['locked'] as bool? ?? false,
    worn: json['worn'] as bool? ?? false,
  );
}

class WeekPlan {
  WeekPlan({required this.weekStart, required this.days});

  DateTime weekStart;
  List<DayPlan> days;

  DayPlan? forDate(DateTime date) {
    for (final day in days) {
      if (sameDay(day.date, date)) return day;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart.toIso8601String(),
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory WeekPlan.fromJson(Map<String, dynamic> json) => WeekPlan(
    weekStart: DateTime.parse(json['weekStart'] as String),
    days: (json['days'] as List)
        .map((e) => DayPlan.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class UserProfile {
  UserProfile({
    this.name = '',
    Set<int>? workdays,
    this.workStyle = Formality.smartCasual,
    this.minRepeatDays = 4,
    this.onboarded = false,
    this.walkthroughSeen = false,
    this.wearer = Wearer.woman,
    this.dateOfBirth,
    this.photoPath,
    this.weightKg,
    this.heightCm,
    this.description = '',
    this.officeAlarmOn = false,
    this.officeAlarmHour = 7,
    this.officeAlarmMinute = 30,
    this.officeAlarmMusicPath,
    this.officeAlarmMusicName,
    this.officeAlarmFiredOn,
    List<String>? customShelves,
  }) : workdays = workdays ?? {1, 2, 3, 4, 5},
       customShelves = customShelves ?? [];

  String name;
  Set<int> workdays;
  Formality workStyle;
  int minRepeatDays;
  bool onboarded;
  bool walkthroughSeen;
  Wearer wearer;
  DateTime? dateOfBirth;
  String? photoPath;
  double? weightKg;
  double? heightCm;
  String description;
  bool officeAlarmOn;
  int officeAlarmHour;
  int officeAlarmMinute;
  String? officeAlarmMusicPath;
  String? officeAlarmMusicName;
  String? officeAlarmFiredOn;
  /// User-created cupboard categories (dynamic), shared for this profile.
  List<String> customShelves;

  double? get bmi {
    final w = weightKg;
    final h = heightCm;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  String get bmiCategory {
    final value = bmi;
    if (value == null) return '';
    if (value < 18.5) return 'Underweight';
    if (value < 25) return 'Normal';
    if (value < 30) return 'Overweight';
    return 'Obese';
  }

  String get bmiLabel {
    final value = bmi;
    if (value == null) return 'Add height and weight';
    return '$bmiCategory · ${value.toStringAsFixed(1)}';
  }

  TimeOfDay get officeAlarmTime =>
      TimeOfDay(hour: officeAlarmHour, minute: officeAlarmMinute);

  Map<String, dynamic> toJson() => {
    'name': name,
    'workdays': workdays.toList(),
    'workStyle': workStyle.name,
    'minRepeatDays': minRepeatDays,
    'onboarded': onboarded,
    'walkthroughSeen': walkthroughSeen,
    'wearer': wearer.name,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'photoPath': photoPath,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'description': description,
    'officeAlarmOn': officeAlarmOn,
    'officeAlarmHour': officeAlarmHour,
    'officeAlarmMinute': officeAlarmMinute,
    'officeAlarmMusicPath': officeAlarmMusicPath,
    'officeAlarmMusicName': officeAlarmMusicName,
    'officeAlarmFiredOn': officeAlarmFiredOn,
    'customShelves': customShelves,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    workdays: ((json['workdays'] as List?) ?? const [1, 2, 3, 4, 5])
        .map((e) => e as int)
        .toSet(),
    workStyle: Formality.values.byName(
      json['workStyle'] as String? ?? Formality.smartCasual.name,
    ),
    minRepeatDays: json['minRepeatDays'] as int? ?? 4,
    onboarded: json['onboarded'] as bool? ?? false,
    walkthroughSeen: json['walkthroughSeen'] as bool? ?? false,
    wearer: Wearer.values.byName(json['wearer'] as String? ?? Wearer.woman.name),
    dateOfBirth: json['dateOfBirth'] == null
        ? null
        : DateTime.tryParse(json['dateOfBirth'] as String),
    photoPath: json['photoPath'] as String?,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    description: json['description'] as String? ?? '',
    officeAlarmOn: json['officeAlarmOn'] as bool? ?? false,
    officeAlarmHour: json['officeAlarmHour'] as int? ?? 7,
    officeAlarmMinute: json['officeAlarmMinute'] as int? ?? 30,
    officeAlarmMusicPath: json['officeAlarmMusicPath'] as String?,
    officeAlarmMusicName: json['officeAlarmMusicName'] as String?,
    officeAlarmFiredOn: json['officeAlarmFiredOn'] as String?,
    customShelves: ((json['customShelves'] as List?) ?? const [])
        .map((e) => e as String)
        .where((e) => e.trim().isNotEmpty)
        .toList(),
  );
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime mondayOf(DateTime date) {
  final d = dateOnly(date);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

String dateKey(DateTime date) {
  final d = dateOnly(date);
  final m = '${d.month}'.padLeft(2, '0');
  final day = '${d.day}'.padLeft(2, '0');
  return '${d.year}-$m-$day';
}

Season seasonFor(DateTime date) {
  final m = date.month;
  if (m >= 3 && m <= 5) return Season.summer;
  if (m >= 6 && m <= 9) return Season.monsoon;
  if (m == 11 || m == 12 || m == 1 || m == 2) return Season.winter;
  return Season.allSeason;
}
