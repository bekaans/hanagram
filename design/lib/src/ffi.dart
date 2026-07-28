// Hanagram — C++ çekirdek köprüsü (dart:ffi)
//
// Bu dosya İNCE bir yapıştırıcıdır: iş mantığı içermez. Tek işi C ABI'yi
// (core/include/hanagram/hanagram.h) Dart tarafına güvenli biçimde açmaktır.
//
// Kural: buraya kural yazılmaz. Bir davranış değişikliği gerekiyorsa C++ tarafında
// yapılır — böylece beş platformda da aynı davranış geçerli olur.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ——— C imzaları ———
typedef _StartNative = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _StartDart = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _StopNative = Void Function(Pointer<Void>);
typedef _StopDart = void Function(Pointer<Void>);

typedef _CallNative = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef _CallDart = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

typedef _AbiNative = Int32 Function();
typedef _AbiDart = int Function();

/// Çekirdek yüklenemediğinde fırlatılır. Uygulama bunu yakalayıp kullanıcıya
/// anlaşılır bir kurulum ekranı gösterir — sessizce sahte veriye düşmez.
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

class HanagramCore {
  HanagramCore._(this._lib, this._handle);

  final DynamicLibrary _lib;
  Pointer<Void> _handle;

  late final _CallDart _call = _lib.lookupFunction<_CallNative, _CallDart>('hg_call');
  late final _FreeDart _free = _lib.lookupFunction<_FreeNative, _FreeDart>('hg_free');
  late final _StopDart _stop = _lib.lookupFunction<_StopNative, _StopDart>('hg_stop');

  static const int expectedAbiMajor = 1;

  /// Çekirdeği başlatır. [dataDir] boşsa yalnızca bellekte çalışır.
  static HanagramCore start(String dataDir) {
    final lib = _openLibrary();

    final abiMajor = lib.lookupFunction<_AbiNative, _AbiDart>('hg_abi_major')();
    if (abiMajor != expectedAbiMajor) {
      throw CoreUnavailable(
          'ABI uyumsuz: çekirdek v$abiMajor, uygulama v$expectedAbiMajor bekliyor');
    }

    final startFn = lib.lookupFunction<_StartNative, _StartDart>('hg_start');
    final dirPtr = dataDir.toNativeUtf8();
    final cfgPtr = '{}'.toNativeUtf8();
    try {
      final handle = startFn(dirPtr, cfgPtr);
      if (handle == nullptr) throw CoreUnavailable('hg_start null döndü');
      return HanagramCore._(lib, handle);
    } finally {
      calloc.free(dirPtr);
      calloc.free(cfgPtr);
    }
  }

  static DynamicLibrary _openLibrary() {
    // Aranacak adlar, platforma göre. Uygulama paketiyle birlikte gelen kütüphane
    // önce denenir; bulunamazsa geliştirme derlemesindeki yola bakılır.
    final candidates = <String>[];
    if (Platform.isMacOS) {
      candidates.addAll(['libhanagram.dylib', '@rpath/libhanagram.dylib']);
    } else if (Platform.isIOS) {
      // iOS'ta çekirdek uygulamaya statik bağlanır.
      return DynamicLibrary.process();
    } else if (Platform.isAndroid) {
      candidates.add('libhanagram.so');
    } else if (Platform.isWindows) {
      candidates.add('hanagram.dll');
    } else if (Platform.isLinux) {
      candidates.add('libhanagram.so');
    }

    // Geliştirme yolu: depoyu klonlayıp core'u derleyen biri için.
    // design/ paketinden bakar: ../../core/build/... (proje köküne çıkar).
    final base = Directory.current.path;
    final devPaths = <String>[
      '$base/../core/build/libhanagram.dylib',
      '$base/../core/build-macos/libhanagram.dylib',
      '$base/../core/build/libhanagram.so',
      '$base/../core/build/hanagram.dll',
    ];

    final errors = <String>[];
    for (final name in [...candidates, ...devPaths]) {
      try {
        return DynamicLibrary.open(name);
      } catch (e) {
        errors.add(name);
      }
    }
    try {
      return DynamicLibrary.process();
    } catch (_) {
      throw CoreUnavailable('kütüphane bulunamadı (denenen: ${errors.join(", ")})');
    }
  }

  /// Çekirdeğe çağrı. Hata durumunda [CoreError] fırlatır.
  Map<String, dynamic> call(String method, [Map<String, dynamic>? payload]) {
    final result = callRaw(method, payload);
    if (result['ok'] != true) {
      throw CoreError(
        (result['code'] ?? 'ERR_UNKNOWN') as String,
        (result['hint'] ?? '') as String,
      );
    }
    return (result['data'] as Map).cast<String, dynamic>();
  }

  /// Ham sonuç — hata da dahil, olduğu gibi. Hatanın akış kontrolü olduğu
  /// yerlerde (davet kodu doğrulama gibi) bu kullanılır.
  Map<String, dynamic> callRaw(String method, [Map<String, dynamic>? payload]) {
    if (_handle == nullptr) throw CoreUnavailable('çekirdek kapatılmış');

    final methodPtr = method.toNativeUtf8();
    final payloadPtr = jsonEncode(payload ?? const {}).toNativeUtf8();
    Pointer<Utf8> resultPtr = nullptr;
    try {
      resultPtr = _call(_handle, methodPtr, payloadPtr);
      if (resultPtr == nullptr) {
        return {'ok': false, 'code': 'ERR_NULL_RESULT'};
      }
      final text = resultPtr.toDartString();
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } finally {
      calloc.free(methodPtr);
      calloc.free(payloadPtr);
      if (resultPtr != nullptr) _free(resultPtr);
    }
  }

  String get version {
    final fn = _lib.lookupFunction<_VersionNative, _VersionDart>('hg_version');
    return fn().toDartString();
  }

  void dispose() {
    if (_handle != nullptr) {
      _stop(_handle);
      _handle = nullptr;
    }
  }
}
