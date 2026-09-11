import 'dart:typed_data';

/// 非Web環境（モバイルネイティブ等）用のスタブ
Future<List<String>> nativeDetectQrFromBytes(Uint8List bytes) async {
  return [];
}
