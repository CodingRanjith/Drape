import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BucketVibe {
  styleChallenge,
  eventLook,
  shopping,
  travel,
  confidence,
  seasonal,
}

extension BucketVibeX on BucketVibe {
  String get label => switch (this) {
    BucketVibe.styleChallenge => 'Style quest',
    BucketVibe.eventLook => 'Event look',
    BucketVibe.shopping => 'Shop find',
    BucketVibe.travel => 'Travel fit',
    BucketVibe.confidence => 'Glow up',
    BucketVibe.seasonal => 'Season vibe',
  };

  String get hint => switch (this) {
    BucketVibe.styleChallenge => 'Try a bold new combo',
    BucketVibe.eventLook => 'Plan a special-day outfit',
    BucketVibe.shopping => 'Find that missing piece',
    BucketVibe.travel => 'Pack a trip-ready look',
    BucketVibe.confidence => 'Wear what makes you shine',
    BucketVibe.seasonal => 'Match the season energy',
  };

  IconData get icon => switch (this) {
    BucketVibe.styleChallenge => Icons.auto_awesome_rounded,
    BucketVibe.eventLook => Icons.celebration_outlined,
    BucketVibe.shopping => Icons.shopping_bag_outlined,
    BucketVibe.travel => Icons.flight_takeoff_rounded,
    BucketVibe.confidence => Icons.favorite_border_rounded,
    BucketVibe.seasonal => Icons.wb_sunny_outlined,
  };

  Color get accent => switch (this) {
    BucketVibe.styleChallenge => AppColors.terracotta,
    BucketVibe.eventLook => const Color(0xFF6B2748),
    BucketVibe.shopping => AppColors.gold,
    BucketVibe.travel => const Color(0xFF3D6EA8),
    BucketVibe.confidence => const Color(0xFFC45C6A),
    BucketVibe.seasonal => AppColors.sage,
  };

  Color get soft => switch (this) {
    BucketVibe.styleChallenge => AppColors.terracottaSoft,
    BucketVibe.eventLook => const Color(0xFFF3E0E8),
    BucketVibe.shopping => const Color(0xFFF5EDDF),
    BucketVibe.travel => const Color(0xFFE3ECF6),
    BucketVibe.confidence => const Color(0xFFF8E6EA),
    BucketVibe.seasonal => AppColors.sageSoft,
  };
}

class StyleBucketItem {
  StyleBucketItem({
    required this.id,
    required this.title,
    this.note = '',
    this.vibe = BucketVibe.styleChallenge,
    this.imagePath,
    DateTime? createdAt,
    this.completedAt,
    this.starred = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String note;
  BucketVibe vibe;
  String? imagePath;
  DateTime createdAt;
  DateTime? completedAt;
  bool starred;

  bool get isCompleted => completedAt != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'vibe': vibe.name,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'starred': starred,
  };

  factory StyleBucketItem.fromJson(Map<String, dynamic> json) =>
      StyleBucketItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Style dream',
        note: json['note'] as String? ?? '',
        vibe: BucketVibe.values.byName(
          json['vibe'] as String? ?? BucketVibe.styleChallenge.name,
        ),
        imagePath: json['imagePath'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.tryParse(json['completedAt'] as String),
        starred: json['starred'] as bool? ?? false,
      );

  StyleBucketItem copyWith({
    String? title,
    String? note,
    BucketVibe? vibe,
    String? imagePath,
    bool clearImage = false,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompleted = false,
    bool? starred,
  }) {
    return StyleBucketItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      vibe: vibe ?? this.vibe,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      starred: starred ?? this.starred,
    );
  }
}
