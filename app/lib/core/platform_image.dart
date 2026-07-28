// Hanagram — platform bağımsız görüntü widget'ı
//
// Koşullu export: native'de dart:io File ile, web'de placeholder.
// Çağrı kodu her iki platformda da aynı: PlatformImage(file: myFile)
export 'platform_image_native.dart'
    if (dart.library.js_interop) 'platform_image_web.dart';
