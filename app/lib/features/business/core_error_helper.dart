// Hanagram — core error helper
//
// CoreError ve CoreUnavailable'dan güvenli mesaj çıkarmak için yardımcı fonksiyon.
// Web'de C++ çekirdek kullanılamaz → CoreUnavailable fırlatılır.
// Bu fonksiyon her iki exception tipinden de kullanıcıya uygun mesaj üretir.
import 'package:hanagram_design/design.dart';

/// Exception'dan kullanıcıya gösterilecek hata mesajını çıkarır.
String extractErrorMessage(Object e) {
  if (e is CoreError) {
    return e.hint.isNotEmpty ? e.hint : e.code;
  }
  if (e is CoreUnavailable) {
    return 'Bu özellik bu platformda kullanılamıyor';
  }
  return 'Beklenmeyen bir hata oluştu';
}
