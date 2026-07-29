// Hanagram — OneSignal koşullu import
//
// Native'de onesignal_flutter, web'de stub.
export 'onesignal_native.dart'
    if (dart.library.js_interop) 'onesignal_web.dart';
