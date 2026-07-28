// Hanagram — FFI stub (web platformu için)
//
// Web'de dart:ffi kullanılamaz.
// Native platformlarda ffi.dart kullanılır.
// Stub: tüm FFI sınıfları ve hataları boş olarak tanımlı.

bool get isFfiAvailable => false;

/// Çekirdek kullanılamadığında fırlatılır.
class CoreUnavailable implements Exception {
  CoreUnavailable(this.detail);
  final String detail;
  @override
  String toString() => 'Çekirdek yüklenemedi: $detail';
}

/// Çekirdeğin döndürdüğü hata (ok:false).
class CoreError implements Exception {
  CoreError(this.code, this.hint);
  final String code;
  final String hint;
  @override
  String toString() => code;
}

/// FFI bridge — web'de kullanılamaz, hata fırlatır.
class HanagramCore {
  HanagramCore._();

  factory HanagramCore.start(String dir) {
    // Web'de çekirdek başlatılmaz — sadece stub döner.
    // call/callRaw çağrıldığında CoreUnavailable fırlatır.
    return HanagramCore._();
  }

  /// Çekirdeğe çağrı — web'de hata fırlatır.
  Map<String, dynamic> call(String method, [Map<String, dynamic>? payload]) {
    throw CoreUnavailable('Web platformunda C++ çekirdeği kullanılamaz');
  }

  /// Ham sonuç — web'de hata fırlatır.
  Map<String, dynamic> callRaw(String method, [Map<String, dynamic>? payload]) {
    throw CoreUnavailable('Web platformunda C++ çekirdeği kullanılamaz');
  }

  String get version => 'web-0.0.0';

  void dispose() {}
}
