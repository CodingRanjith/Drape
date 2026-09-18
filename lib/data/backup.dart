import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/bucket_list.dart';
import '../models/life.dart';
import '../models/wardrobe.dart';
import 'excel_backup.dart';
import 'excel_sheet.dart';
import 'media_bytes.dart';
import 'stored_bytes.dart';

class PackedBackup {
  PackedBackup({required this.json, required this.files});

  final Map<String, dynamic> json;
  final Map<String, Uint8List> files;

  bool get hasProfile => json['profile'] is Map;

  Uint8List? fileFor(String? name, {String? id}) =>
      matchFile(name, id: id)?.value;

  MapEntry<String, Uint8List>? matchFile(String? name, {String? id}) {
    if (name != null && name.isNotEmpty) {
      final wanted = normalizeZipPath(name);
      final wantedBase = zipBaseName(wanted);
      for (final entry in files.entries) {
        final key = normalizeZipPath(entry.key);
        if (key == wanted ||
            entry.key == name ||
            key.endsWith('/$wanted') ||
            key.endsWith('/$wantedBase') ||
            zipBaseName(key) == wantedBase) {
          return MapEntry(key, entry.value);
        }
      }
    }
    if (id == null || id.isEmpty) return null;
    for (final entry in files.entries) {
      final key = normalizeZipPath(entry.key);
      final base = zipBaseName(key);
      final stem = base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
      if (stem == id) return MapEntry(key, entry.value);
    }
    return null;
  }

  Iterable<MapEntry<String, Uint8List>> imageFiles() =>
      files.entries.where((e) => isImageZipEntry(e.key));
}

class DrapeBackup {
  static const version = 1;
  static const jsonName = 'backup.json';

  static Future<Uint8List> encode({
    required UserProfile profile,
    required List<Garment> garments,
    WeekPlan? week,
    required List<LifeEvent> events,
    required List<PartyLook> partyLooks,
    required Set<String> completedDays,
    List<ClothSet> clothSets = const [],
    List<StyleBucketItem> bucketList = const [],
  }) async {
    final files = <String, Uint8List>{};

    Future<String?> pack(String? path, String zipPath) async {
      final bytes = await readStoredBytes(path);
      if (bytes == null || bytes.isEmpty) return null;
      files[zipPath] = bytes;
      return zipPath;
    }

    final garmentMaps = <Map<String, dynamic>>[];
    for (final garment in garments) {
      final map = garment.toJson();
      map['imagePath'] = await pack(
        garment.imagePath,
        'media/garments/${garment.id}.${fileExt(garment.imagePath)}',
      );
      garmentMaps.add(map);
    }

    final lookMaps = <Map<String, dynamic>>[];
    for (final look in partyLooks) {
      final map = look.toJson();
      map['imagePath'] = await pack(
        look.imagePath,
        'media/party/${look.id}.${fileExt(look.imagePath)}',
      );
      lookMaps.add(map);
    }

    final eventMaps = <Map<String, dynamic>>[];
    for (final event in events) {
      final map = event.toJson();
      final ext = fileExt(event.musicPath, fallback: 'mp3');
      map['musicPath'] = await pack(event.musicPath, 'media/music/${event.id}.$ext');
      eventMaps.add(map);
    }

    final profileMap = profile.toJson();
    profileMap['photoPath'] = await pack(
      profile.photoPath,
      'media/profile/avatar.${fileExt(profile.photoPath)}',
    );
    profileMap['officeAlarmMusicPath'] = await pack(
      profile.officeAlarmMusicPath,
      'media/profile/office-alarm.${fileExt(profile.officeAlarmMusicPath, fallback: 'mp3')}',
    );

    final json = <String, dynamic>{
      'version': version,
      'createdAt': DateTime.now().toIso8601String(),
      'profile': profileMap,
      'garments': garmentMaps,
      'week': week?.toJson(),
      'events': eventMaps,
      'partyLooks': lookMaps,
      'completedDays': completedDays.toList(),
      'clothSets': clothSets.map((s) => s.toJson()).toList(),
      'bucketList': bucketList.map((b) => b.toJson()).toList(),
    };

    return zipOf(json, files);
  }

  static Uint8List zipOf(Map<String, dynamic> json, Map<String, Uint8List> files) {
    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(jsonName, jsonBytes.length, jsonBytes));
    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile(normalizeZipPath(entry.key), entry.value.length, entry.value),
      );
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded.isEmpty) {
      throw const FormatException('Could not make the backup zip.');
    }
    return Uint8List.fromList(encoded);
  }

  static PackedBackup decode(Uint8List bytes) {
    if (SimpleXlsx.isXlsx(bytes)) {
      return PackedBackup(json: jsonFromExcel(bytes), files: {});
    }
    if (isZipBytes(bytes)) {
      return _fromZip(bytes);
    }
    final text = utf8.decode(bytes);
    final json = jsonDecode(text) as Map<String, dynamic>;
    final files = <String, Uint8List>{};
    final embedded = json['files'];
    if (embedded is Map) {
      for (final item in embedded.entries) {
        final value = item.value;
        if (value is String) {
          files[item.key as String] = base64Decode(value);
        }
      }
    }
    return PackedBackup(json: json, files: files);
  }

  static PackedBackup _fromZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    Map<String, dynamic>? json;
    final files = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = normalizeZipPath(file.name);
      if (name.contains('__MACOSX') || zipBaseName(name).startsWith('.')) {
        continue;
      }
      final content = Uint8List.fromList(file.content as List<int>);
      if (zipBaseName(name).toLowerCase() == jsonName) {
        json = jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
      } else {
        files[name] = content;
      }
    }
    json ??= {
      'version': version,
      'filesOnly': true,
      'garments': const [],
      'events': const [],
      'partyLooks': const [],
      'completedDays': const [],
      'clothSets': const [],
      'bucketList': const [],
    };
    return PackedBackup(json: json, files: files);
  }
}
