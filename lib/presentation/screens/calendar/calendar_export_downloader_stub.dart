import 'dart:typed_data';

/// 모바일/데스크톱 stub — 웹에서만 실제 구현
Future<void> downloadFileWeb(
    String filename, List<int> bytes, String mimeType) async {}

Future<bool> copyImageToClipboard(Uint8List bytes) async => false;
