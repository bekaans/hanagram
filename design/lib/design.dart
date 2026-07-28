/// Hanagram tasarım sistemi.
///
/// Tek import ile erişim:
/// ```dart
/// import 'package:hanagram_design/design.dart';
/// ```
library hanagram_design;

export 'src/tokens.dart';
export 'src/brand.dart';
export 'src/ui_components.dart';
// Web'de dart:ffi kullanılamaz — koşullu export
export 'src/ffi.dart' if (dart.library.js_interop) 'src/ffi_stub.dart';
