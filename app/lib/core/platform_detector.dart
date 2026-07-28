// Hanagram — platform tespiti (native: Android, iOS, macOS, Windows)
import 'dart:io';

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
