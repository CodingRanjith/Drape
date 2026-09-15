import 'dart:math';

import 'package:drape/data/sample_closet.dart';
import 'package:drape/logic/stylist.dart';
import 'package:drape/models/wardrobe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds matching sets and fills Monday to Friday', () {
    final stylist = Stylist(random: Random(7));
    final closet = sampleCloset();
    final profile = UserProfile();
    final weekStart = DateTime(2026, 8, 17);

    final choices = stylist.buildChoices(
      wardrobe: closet,
      profile: profile,
      date: weekStart,
    );
    expect(choices, isNotEmpty);

    final week = stylist.planWeek(
      wardrobe: closet,
      profile: profile,
      weekStart: weekStart,
    );
    final workLooks = week.days
        .where((d) => d.date.weekday <= DateTime.friday)
        .toList();
    expect(workLooks, hasLength(5));
    expect(workLooks.every((d) => d.outfit != null && !d.outfit!.isEmpty), isTrue);
    expect(
      week.days.singleWhere((d) => d.date.weekday == DateTime.saturday).outfit,
      isNull,
    );
  });
}
