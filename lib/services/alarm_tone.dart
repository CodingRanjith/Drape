import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

Uint8List buildAlarmWav({int seconds = 2}) {
  const sampleRate = 22050;
  final n = sampleRate * seconds;
  final dataBytes = n * 2;
  final buffer = ByteData(44 + dataBytes);

  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      buffer.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  buffer.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  buffer.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final beat = (i % (sampleRate ~/ 2)) < (sampleRate ~/ 3);
    final sample = beat
        ? (sin(2 * pi * 880 * t) * 0.42 * 32767).round()
        : 0;
    buffer.setInt16(44 + i * 2, sample.clamp(-32767, 32767), Endian.little);
  }
  return buffer.buffer.asUint8List();
}

Uint8List? audioBytesFromStored(String? path) {
  if (path == null || path.isEmpty || !path.startsWith('data:')) return null;
  final comma = path.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(path.substring(comma + 1));
  } catch (_) {
    return null;
  }
}
