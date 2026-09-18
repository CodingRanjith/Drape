import 'dart:typed_data';

import 'package:mine/data/backup.dart';
import 'package:mine/data/excel_backup.dart';
import 'package:mine/data/excel_sheet.dart';
import 'package:mine/models/wardrobe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup zip keeps clothes names and photo bytes', () {
    final photo = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final garment = Garment(
      id: 'g1',
      name: 'White office top',
      category: GarmentCategory.top,
      colors: const [0xFFFFFFFF],
      imagePath: 'media/garments/g1.jpg',
    );
    final json = {
      'version': 1,
      'profile': UserProfile(name: 'Asha', onboarded: true).toJson(),
      'garments': [garment.toJson()],
      'week': null,
      'events': const [],
      'partyLooks': const [],
      'completedDays': const ['2026-08-21'],
    };

    final zip = MineBackup.zipOf(json, {'media/garments/g1.jpg': photo});
    final packed = MineBackup.decode(zip);

    expect(packed.json['garments'], isNotEmpty);
    expect(packed.fileFor('media/garments/g1.jpg'), photo);
    expect(packed.fileFor('g1.jpg', id: 'g1'), photo);
    expect(packed.json['completedDays'], ['2026-08-21']);
  });

  test('excel sheet round-trip keeps clothes names', () {
    final garment = Garment(
      id: 'g9',
      name: 'Linen shirt',
      category: GarmentCategory.top,
      colors: const [0xFFFFFFFF],
    );
    final bytes = encodeExcelBackup(
      profile: UserProfile(name: 'Asha', onboarded: true, heightCm: 162),
      garments: [garment],
      events: const [],
      partyLooks: const [],
      completedDays: const {'2026-08-21'},
    );
    expect(SimpleXlsx.isXlsx(bytes), isTrue);

    final packed = MineBackup.decode(bytes);
    final clothes = packed.json['garments'] as List;
    expect(clothes, isNotEmpty);
    expect(clothes.first['name'], 'Linen shirt');
    expect(packed.json['profile']['name'], 'Asha');
    expect(packed.json['completedDays'], ['2026-08-21']);
  });

  test('import zip with nested folders still finds photos', () {
    final photo = Uint8List.fromList([1, 2, 3, 9]);
    final json = {
      'version': 1,
      'profile': UserProfile(name: 'Asha', onboarded: true).toJson(),
      'garments': [
        Garment(
          id: 'g2',
          name: 'Blue shirt',
          category: GarmentCategory.top,
          colors: const [0xFF0000FF],
          imagePath: 'media/garments/g2.jpg',
        ).toJson(),
      ],
    };
    final zip = MineBackup.zipOf(json, {'Folder/media/garments/g2.jpg': photo});
    final packed = MineBackup.decode(zip);
    expect(packed.fileFor('media/garments/g2.jpg', id: 'g2'), photo);
  });

  test('zip of uploaded photos can be imported without backup.json', () {
    final photo = Uint8List.fromList([7, 7, 7, 7]);
    final zip = MineBackup.zipOf(
      {'filesOnly': true, 'garments': const []},
      {'photos/office-top.jpg': photo},
    );
    final packed = MineBackup.decode(zip);
    expect(packed.hasProfile, isFalse);
    expect(packed.imageFiles().single.value, photo);
  });
}
