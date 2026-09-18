import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'media_bytes.dart';

/// Minimal .xlsx writer/reader so wardrobe data can open in Excel
/// without pulling in a spreadsheet package.
class SimpleXlsx {
  SimpleXlsx._();

  static bool isXlsx(Uint8List bytes) {
    if (!isZipBytes(bytes)) return false;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive.files.any((file) {
        final name = normalizeZipPath(file.name).toLowerCase();
        return name == 'xl/workbook.xml' || name.endsWith('/xl/workbook.xml');
      });
    } catch (_) {
      return false;
    }
  }

  static Uint8List encode(Map<String, List<List<String>>> sheets) {
    if (sheets.isEmpty) {
      throw const FormatException('Excel sheet is empty.');
    }
    final names = sheets.keys.map(_clipName).toList();
    final archive = Archive();
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        0,
        utf8.encode(_contentTypesXml(names.length)),
      ),
    );
    archive.addFile(ArchiveFile('_rels/.rels', 0, utf8.encode(_rootRelsXml)));
    archive.addFile(
      ArchiveFile('xl/workbook.xml', 0, utf8.encode(_workbookXml(names))),
    );
    archive.addFile(
      ArchiveFile(
        'xl/_rels/workbook.xml.rels',
        0,
        utf8.encode(_workbookRelsXml(names.length)),
      ),
    );
    for (var i = 0; i < names.length; i++) {
      final xml = _sheetXml(sheets[sheets.keys.elementAt(i)] ?? const []);
      final bytes = utf8.encode(xml);
      archive.addFile(
        ArchiveFile('xl/worksheets/sheet${i + 1}.xml', bytes.length, bytes),
      );
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded.isEmpty) {
      throw const FormatException('Could not make the Excel file.');
    }
    return Uint8List.fromList(encoded);
  }

  static Map<String, List<List<String>>> decode(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = <String, String>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      files[normalizeZipPath(file.name).toLowerCase()] = utf8.decode(
        file.content as List<int>,
      );
    }
    final workbook = files['xl/workbook.xml'];
    if (workbook == null) {
      throw const FormatException('This Excel file has no workbook.');
    }
    final shared = _sharedStrings(files['xl/sharedstrings.xml'] ?? '');
    final relTargets = _relTargets(files['xl/_rels/workbook.xml.rels'] ?? '');
    final sheets = <String, List<List<String>>>{};
    var index = 0;
    for (final match in _sheetTagRe.allMatches(workbook)) {
      index += 1;
      final tag = match.group(0)!;
      final name = _unescape(_attr(tag, 'name') ?? 'Sheet$index');
      final rid = _attr(tag, 'r:id') ?? _attr(tag, 'id');
      var target = rid == null ? null : relTargets[rid];
      target ??= 'xl/worksheets/sheet$index.xml';
      if (!target.toLowerCase().startsWith('xl/')) {
        target = 'xl/${target.replaceFirst(RegExp(r'^/+'), '')}';
      }
      final xml = files[target.toLowerCase()];
      if (xml == null) continue;
      sheets[_uniqueName(name, sheets.keys)] = _parseSheet(xml, shared);
    }
    if (sheets.isEmpty) {
      throw const FormatException('Could not read any Excel rows.');
    }
    return sheets;
  }

  static String _clipName(String name) {
    var next = name.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
    if (next.isEmpty) next = 'Sheet';
    if (next.length > 31) next = next.substring(0, 31);
    return next;
  }

  static String _uniqueName(String name, Iterable<String> taken) {
    final base = _clipName(name);
    var candidate = base;
    var i = 2;
    while (taken.contains(candidate)) {
      final suffix = ' $i';
      final keep = (31 - suffix.length).clamp(1, base.length);
      candidate = '${base.substring(0, keep)}$suffix';
      i += 1;
    }
    return candidate;
  }

  static String _contentTypesXml(int count) {
    final overrides = StringBuffer()
      ..writeln(
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
      );
    for (var i = 1; i <= count; i++) {
      overrides.writeln(
        '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '$overrides'
        '</Types>';
  }

  static const _rootRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbookXml(List<String> names) {
    final sheets = StringBuffer();
    for (var i = 0; i < names.length; i++) {
      sheets.write(
        '<sheet name="${_escape(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
      );
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets>$sheets</sheets>'
        '</workbook>';
  }

  static String _workbookRelsXml(int count) {
    final rels = StringBuffer();
    for (var i = 1; i <= count; i++) {
      rels.write(
        '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>',
      );
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels'
        '</Relationships>';
  }

  static String _sheetXml(List<List<String>> rows) {
    final data = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      data.write('<row r="${r + 1}">');
      for (var c = 0; c < row.length; c++) {
        final ref = '${_colName(c)}${r + 1}';
        data.write(
          '<c r="$ref" t="inlineStr"><is><t>${_escape(row[c])}</t></is></c>',
        );
      }
      data.write('</row>');
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>$data</sheetData>'
        '</worksheet>';
  }

  static String _colName(int index) {
    var n = index + 1;
    final buffer = StringBuffer();
    while (n > 0) {
      final m = (n - 1) % 26;
      buffer.writeCharCode(65 + m);
      n = (n - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  static final _sheetTagRe = RegExp(r'<sheet\b[^>/]*/?>', caseSensitive: false);
  static final _rowRe = RegExp(r'<row\b[^>]*>([\s\S]*?)</row>', caseSensitive: false);
  static final _cellRe = RegExp(r'<c\b([^>]*)>([\s\S]*?)</c>', caseSensitive: false);
  static final _siRe = RegExp(r'<si\b[^>]*>([\s\S]*?)</si>', caseSensitive: false);
  static final _tRe = RegExp(r'<t\b[^>]*>([\s\S]*?)</t>', caseSensitive: false);
  static final _vRe = RegExp(r'<v\b[^>]*>([\s\S]*?)</v>', caseSensitive: false);
  static final _relRe = RegExp(
    r'<Relationship\b[^>]*>',
    caseSensitive: false,
  );

  static Map<String, String> _relTargets(String xml) {
    final map = <String, String>{};
    for (final match in _relRe.allMatches(xml)) {
      final tag = match.group(0)!;
      final id = _attr(tag, 'Id');
      final target = _attr(tag, 'Target');
      if (id != null && target != null) map[id] = target.replaceAll('\\', '/');
    }
    return map;
  }

  static List<String> _sharedStrings(String xml) {
    if (xml.isEmpty) return const [];
    return [
      for (final match in _siRe.allMatches(xml))
        _unescape(
          _tRe
              .allMatches(match.group(1)!)
              .map((m) => m.group(1) ?? '')
              .join(),
        ),
    ];
  }

  static List<List<String>> _parseSheet(String xml, List<String> shared) {
    final rows = <int, Map<int, String>>{};
    var maxCol = 0;
    for (final rowMatch in _rowRe.allMatches(xml)) {
      for (final cellMatch in _cellRe.allMatches(rowMatch.group(1)!)) {
        final attrs = cellMatch.group(1)!;
        final body = cellMatch.group(2)!;
        final ref = _attr(attrs, 'r');
        if (ref == null) continue;
        final parsed = _parseRef(ref);
        if (parsed == null) continue;
        final type = _attr(attrs, 't') ?? '';
        var text = '';
        if (type == 'inlineStr' || type == 'str') {
          text = _unescape(
            _tRe.allMatches(body).map((m) => m.group(1) ?? '').join(),
          );
        } else if (type == 's') {
          final index = int.tryParse(_vRe.firstMatch(body)?.group(1) ?? '');
          if (index != null && index >= 0 && index < shared.length) {
            text = shared[index];
          }
        } else {
          text = _unescape(_vRe.firstMatch(body)?.group(1) ?? '');
        }
        rows.putIfAbsent(parsed.$2, () => {})[parsed.$1] = text;
        if (parsed.$1 > maxCol) maxCol = parsed.$1;
      }
    }
    if (rows.isEmpty) return const [];
    final maxRow = rows.keys.reduce((a, b) => a > b ? a : b);
    return [
      for (var r = 0; r <= maxRow; r++)
        [
          for (var c = 0; c <= maxCol; c++) rows[r]?[c] ?? '',
        ],
    ];
  }

  static (int, int)? _parseRef(String ref) {
    final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(ref);
    if (match == null) return null;
    var col = 0;
    for (final code in match.group(1)!.toUpperCase().codeUnits) {
      col = col * 26 + (code - 64);
    }
    final row = int.tryParse(match.group(2)!);
    if (row == null || row < 1) return null;
    return (col - 1, row - 1);
  }

  static String? _attr(String tag, String name) {
    final match = RegExp(
      '$name="([^"]*)"',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1);
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  static String _unescape(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
