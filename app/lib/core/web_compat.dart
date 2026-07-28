// Hanagram — web uyumluluk katmanı
//
// Koşullu import: native'de dart:io, web'de stub.
// Tüm dosyalar buradan import etmeli.
export 'web_compat_native.dart'
    if (dart.library.js_interop) 'web_compat_web.dart';

// File tipini her iki platformda da erişilebilir yap
export 'web_compat_file.dart';
