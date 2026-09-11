import 'dart:js_interop';
import 'dart:typed_data';

@JS('detectQrFromBytes')
external JSPromise<JSArray<JSString>>? _detectQrFromBytes(JSUint8Array uint8Array);

Future<List<String>> nativeDetectQrFromBytes(Uint8List bytes) async {
  try {
    final jsArray = bytes.toJS;
    final promise = _detectQrFromBytes(jsArray);
    if (promise == null) return [];

    final resultJsArray = await promise.toDart;
    final list = resultJsArray.toDart.map((e) => e.toDart).toList();
    return list;
  } catch (e) {
    return [];
  }
}
