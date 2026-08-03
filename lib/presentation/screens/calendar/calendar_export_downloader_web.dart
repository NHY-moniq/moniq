import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 웹 브라우저 다운로드 트리거
Future<void> downloadFileWeb(
  String filename,
  List<int> bytes,
  String mimeType,
) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

/// 이미지를 클립보드에 복사 (Chrome/Edge 지원)
Future<bool> copyImageToClipboard(Uint8List bytes) async {
  try {
    // ClipboardItem 미지원 브라우저 (구형 Firefox 등) 조기 리턴
    if (!web.window.hasProperty('ClipboardItem'.toJS).toDart) return false;

    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );

    // new ClipboardItem({'image/png': blob})
    final items = JSObject()..setProperty('image/png'.toJS, blob);
    final item = web.ClipboardItem(items);

    // navigator.clipboard.write([item])
    await web.window.navigator.clipboard.write([item].toJS).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
