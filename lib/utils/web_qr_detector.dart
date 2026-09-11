import 'dart:typed_data';
import 'web_qr_detector_stub.dart'
    if (dart.library.js_interop) 'web_qr_detector_web.dart';

/// 静止画のバイトデータからQRコードを高速検出（Web: BarcodeDetector, モバイル: スタブ）
class WebQrDetector {
  static Future<List<String>> detectQr(Uint8List bytes) async {
    return nativeDetectQrFromBytes(bytes);
  }
}
