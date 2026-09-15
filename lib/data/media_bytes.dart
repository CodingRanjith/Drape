import 'dart:convert';
import 'dart:typed_data';

Uint8List? bytesFromDataUri(String? path) {
  if (path == null || path.isEmpty || !path.startsWith('data:')) return null;
  final comma = path.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(path.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

bool isZipBytes(Uint8List bytes) =>
    bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

String normalizeZipPath(String name) =>
    name.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');

String zipBaseName(String name) {
  final clean = normalizeZipPath(name);
  final slash = clean.lastIndexOf('/');
  return slash >= 0 ? clean.substring(slash + 1) : clean;
}

bool isJunkZipEntry(String name) {
  final clean = normalizeZipPath(name);
  final base = zipBaseName(clean);
  return clean.contains('__MACOSX') ||
      base.startsWith('.') ||
      base == 'Thumbs.db' ||
      base.toLowerCase() == 'backup.json';
}

bool isImageZipEntry(String name) {
  if (isJunkZipEntry(name)) return false;
  final lower = zipBaseName(name).toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.bmp');
}

bool isAudioZipEntry(String name) {
  if (isJunkZipEntry(name)) return false;
  final lower = zipBaseName(name).toLowerCase();
  return lower.endsWith('.mp3') ||
      lower.endsWith('.m4a') ||
      lower.endsWith('.aac') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.ogg');
}

String fileExt(String? path, {String fallback = 'jpg'}) {
  if (path == null || path.isEmpty) return fallback;
  if (path.startsWith('data:')) {
    if (path.startsWith('data:audio/wav')) return 'wav';
    if (path.startsWith('data:audio/mpeg')) return 'mp3';
    if (path.startsWith('data:audio/mp4') || path.startsWith('data:audio/m4a')) {
      return 'm4a';
    }
    if (path.startsWith('data:audio/aac')) return 'aac';
    if (path.startsWith('data:audio/ogg')) return 'ogg';
    if (path.startsWith('data:image/png')) return 'png';
    if (path.startsWith('data:image/webp')) return 'webp';
    if (path.startsWith('data:image/gif')) return 'gif';
    return fallback;
  }
  final clean = path.split('?').first.replaceAll('\\', '/');
  final base = zipBaseName(clean);
  final dot = base.lastIndexOf('.');
  if (dot > 0 && dot < base.length - 1) {
    final ext = base.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext)) return ext;
  }
  return fallback;
}

String audioMime(String ext) => switch (ext) {
  'wav' => 'audio/wav',
  'm4a' => 'audio/mp4',
  'aac' => 'audio/aac',
  'ogg' => 'audio/ogg',
  _ => 'audio/mpeg',
};
