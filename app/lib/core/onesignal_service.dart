// Hanagram — OneSignal koşullu import
//
// Native'de (Android/iOS/macOS/Windows) onesignal_service_native.dart,
// web'de onesignal_service_web.dart kullanılır — web build'i gerçek
// onesignal_flutter paketini asla import etmez.
export 'onesignal_service_native.dart'
    if (dart.library.js_interop) 'onesignal_service_web.dart';
