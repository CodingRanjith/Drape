import 'package:uuid/uuid.dart';

import '../models/wardrobe.dart';

List<Garment> sampleCloset() {
  const uuid = Uuid();
  Garment item({
    required String name,
    required GarmentCategory category,
    required List<int> colors,
    Formality formality = Formality.smartCasual,
    Season season = Season.allSeason,
  }) {
    return Garment(
      id: uuid.v4(),
      name: name,
      category: category,
      colors: colors,
      formality: formality,
      season: season,
    );
  }

  return [
    item(name: 'Grey merino sweater', category: GarmentCategory.top, colors: [0xFF8A8A8A], season: Season.winter),
    item(name: 'White oxford shirt', category: GarmentCategory.top, colors: [0xFFF5F5F0], formality: Formality.formal),
    item(name: 'Sky linen shirt', category: GarmentCategory.top, colors: [0xFF8BB4D4], season: Season.summer),
    item(name: 'Olive utility shirt', category: GarmentCategory.top, colors: [0xFF6B7A4A]),
    item(name: 'Navy knit polo', category: GarmentCategory.top, colors: [0xFF1F3358]),
    item(name: 'Ivory silk blouse', category: GarmentCategory.top, colors: [0xFFF3E6D4], formality: Formality.formal),
    item(name: 'Black crew tee', category: GarmentCategory.top, colors: [0xFF1A1A1A], formality: Formality.casual),
    item(name: 'Wine wrap top', category: GarmentCategory.top, colors: [0xFF6B2748]),
    item(name: 'Charcoal kurta', category: GarmentCategory.dress, colors: [0xFF4A4A4A]),
    item(name: 'Terracotta midi dress', category: GarmentCategory.dress, colors: [0xFFC45C26], season: Season.summer),
    item(name: 'Navy shirt dress', category: GarmentCategory.dress, colors: [0xFF1F3358], formality: Formality.formal),
    item(name: 'Beige linen kurta', category: GarmentCategory.dress, colors: [0xFFD4C4A8]),
    item(name: 'Black midi dress', category: GarmentCategory.dress, colors: [0xFF1A1A1A], formality: Formality.formal),
    item(name: 'Olive wrap dress', category: GarmentCategory.dress, colors: [0xFF6B7A4A]),
    item(name: 'Ivory kurta set', category: GarmentCategory.dress, colors: [0xFFF3E6D4]),
    item(name: 'Navy trousers', category: GarmentCategory.bottom, colors: [0xFF1F3358], formality: Formality.formal),
    item(name: 'Beige chinos', category: GarmentCategory.bottom, colors: [0xFFD4C4A8]),
    item(name: 'Black tailored pants', category: GarmentCategory.bottom, colors: [0xFF1A1A1A], formality: Formality.formal),
    item(name: 'Olive wide pants', category: GarmentCategory.bottom, colors: [0xFF6B7A4A]),
    item(name: 'Ivory palazzo', category: GarmentCategory.bottom, colors: [0xFFF3E6D4], season: Season.summer),
    item(name: 'Navy blazer', category: GarmentCategory.outerwear, colors: [0xFF1F3358], formality: Formality.formal, season: Season.winter),
    item(name: 'Camel overlay', category: GarmentCategory.outerwear, colors: [0xFFC4A06A], season: Season.winter),
    item(name: 'Black loafers', category: GarmentCategory.shoes, colors: [0xFF1A1A1A], formality: Formality.formal),
    item(name: 'White sneakers', category: GarmentCategory.shoes, colors: [0xFFF5F5F0], formality: Formality.casual),
    item(name: 'Tan brogues', category: GarmentCategory.shoes, colors: [0xFFC4A06A]),
    item(name: 'Gold watch', category: GarmentCategory.accessory, colors: [0xFFB0894F]),
    item(name: 'Brown belt', category: GarmentCategory.accessory, colors: [0xFF6B4A32]),
  ];
}
