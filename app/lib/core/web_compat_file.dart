// Hanagram — File tipi köprüsü
//
// Native'de dart:io File, web'de PlatformFile.
// Tüm dosyalar bu dosyadan File import eder.

export 'web_compat_file_native.dart'
    if (dart.library.js_interop) 'web_compat_file_web.dart';
