import 'web_camera_cleaner_stub.dart'
    if (dart.library.js_interop) 'web_camera_cleaner_web.dart';

class WebCameraCleaner {
  /// Web環境においてブラウザの全カメラストリームを物理停止し、DOM上のvideo/platform-view要素を完全除去
  static void forceCleanup() {
    nativeForceCleanup();
  }
}
