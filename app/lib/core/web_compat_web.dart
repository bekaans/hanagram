// Hanagram — web platform stub
// dart:io kullanılamaz, basit stub'lar sağlar.

/// Web'de File stub — compile-only.
class PlatformFile {
  PlatformFile(String path);
  String get path => '';
  bool existsSync() => false;
  int lengthSync() => 0;
  List<int> readAsBytesSync() => [];
  String readAsStringSync() => '';
}

/// Platform tespiti — web her zaman 'web' döndürür.
class PlatformDetect {
  PlatformDetect._();
  static String get current => 'web';
}
