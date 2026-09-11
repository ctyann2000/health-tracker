import 'dart:js_interop';

@JS('setErudaVisible')
external void _setErudaVisible(JSBoolean visible);

void setErudaVisible(bool visible) {
  try {
    _setErudaVisible(visible.toJS);
  } catch (_) {}
}
