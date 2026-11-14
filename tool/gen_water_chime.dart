import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 22050;
  const seconds = 1.4;
  final n = (sampleRate * seconds).round();
  final dataBytes = n * 2;
  final buffer = ByteData(44 + dataBytes);
  void ascii(int o, String t) {
    for (var i = 0; i < t.length; i++) {
      buffer.setUint8(o + i, t.codeUnitAt(i));
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
    final env = exp(-2.8 * t) * (1 - exp(-18 * t));
    var s = 0.55 * sin(2 * pi * 880 * t) * env;
    s += 0.35 * sin(2 * pi * 1320 * t) * exp(-4.2 * t);
    s += 0.18 * sin(2 * pi * 660 * t + 0.4) * exp(-3.0 * t);
    if (t < 0.08) {
      s += 0.08 * sin(2 * pi * 2400 * t) * (1 - t / 0.08);
    }
    final v = (s.clamp(-1.0, 1.0) * 28000).round();
    buffer.setInt16(44 + i * 2, v, Endian.little);
  }
  final out = File('android/app/src/main/res/raw/water_chime.wav');
  out.writeAsBytesSync(buffer.buffer.asUint8List());
  // also copy for assets in-app playback
  Directory('assets/sounds').createSync(recursive: true);
  File('assets/sounds/water_chime.wav').writeAsBytesSync(buffer.buffer.asUint8List());
  print('wrote ${out.path} (${out.lengthSync()} bytes)');
}
