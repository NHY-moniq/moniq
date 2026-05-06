// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// 웹 브라우저 다운로드 트리거
Future<void> downloadFileWeb(
    String filename, List<int> bytes, String mimeType) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// 이미지를 클립보드에 복사 (Chrome/Edge 지원)
/// dart:html 에 ClipboardItem 바인딩이 없으므로 js_util 로 직접 호출
Future<bool> copyImageToClipboard(Uint8List bytes) async {
  try {
    // ClipboardItem 미지원 브라우저 (Firefox 등) 조기 리턴
    if (!js_util.hasProperty(html.window, 'ClipboardItem')) return false;

    final blob = html.Blob([bytes], 'image/png');

    // {'image/png': blob} JS 객체
    final dataObj = js_util.newObject<Object>();
    js_util.setProperty(dataObj, 'image/png', blob);

    // new ClipboardItem({'image/png': blob})
    final ctor = js_util.getProperty<Object>(html.window, 'ClipboardItem');
    final item = js_util.callConstructor<Object>(ctor, [dataObj]);

    // new Array(item) → [item]  (item이 객체일 때 단일 원소 배열)
    final arrCtor = js_util.getProperty<Object>(html.window, 'Array');
    final arr = js_util.callConstructor<Object>(arrCtor, [item]);

    // navigator.clipboard.write([item])
    final clipboard =
        js_util.getProperty<Object>(html.window.navigator, 'clipboard');
    final promise =
        js_util.callMethod<Object>(clipboard, 'write', [arr]);
    await js_util.promiseToFuture<void>(promise);
    return true;
  } catch (_) {
    return false;
  }
}
