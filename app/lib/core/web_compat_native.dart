// Hanagram — native platform uyumluluk (dart:io)
import 'dart:io';

// File'ı doğrudan export et — native'de dart:io File kullanılır
export 'dart:io' show File;

/// Platform tespiti.
class PlatformDetect {
  PlatformDetect._();
  static String get current {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }
}
