import 'dart:html' as html;
import 'dart:typed_data';

Future<void> shareBackupBytesImpl(Uint8List zip, String fileName) async {
  final blob = html.Blob([zip], 'application/zip');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
