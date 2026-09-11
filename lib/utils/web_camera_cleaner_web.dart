import 'dart:js_interop';

@JS('forceStopAllCamerasAndRemoveVideos')
external void _forceStopAllCamerasAndRemoveVideos();

void nativeForceCleanup() {
  try {
    _forceStopAllCamerasAndRemoveVideos();
  } catch (_) {
    // 安全のため例外を握りつぶす
  }
}
