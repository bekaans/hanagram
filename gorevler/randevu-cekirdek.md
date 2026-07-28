---
yaz: core/src/domain/business/appointment.cpp
oku: core/src/domain/business/appointment.hpp, core/src/util/json.hpp, core/tests/test_appointment.cpp
dogrula: cmake --build core/build --target hanagram_tests 2>&1 && ./core/build/hanagram_tests
basari: TUMU GECTI
deneme: 5
---

`core/src/domain/business/appointment.hpp` icindeki TUM fonksiyonlarin
govdesini yaz. Baslik dosyasi bir SOZLESMEDIR: imzalari, alan adlarini ve
davranis kurallarini degistirme.

Testler `core/tests/test_appointment.cpp` icinde ve kabul kapisidir. Onlari da
oku; belirsiz kalan her davranisin dogru cevabi orada yaziyor. Test dosyasina
DOKUNMA.

Kurallar:
- Yalnizca C++20 standart kutuphanesi. Ucuncu taraf bagimlilik yok.
- `<ctime>`, `localtime`, `gmtime` KULLANMA. Tum gun/hafta hesabi tam sayi
  aritmetigidir; saat dilimi `tzOffsetMinutes` olarak veriden gelir.
- Negatif zaman damgalarinda tam bolme yukari yuvarlar; asagi yuvarlayan
  kendi yardimci fonksiyonunu yaz.
- Derleyici uyarisi birakma. Derleme bayraklari:
  -Wall -Wextra -Wpedantic -Wshadow -Wconversion
  Ozellikle -Wconversion: int64_t ile int arasinda ortuk donusum yapma,
  static_cast ile acikca donustur.
- Tanimlayicilar ve yorumlar disindaki her sey Ingilizce; yorumlar Turkce
  yazilabilir ama Turkce karakterli DEGISKEN ADI kullanma.
- JSON yuzeyi: json::Value::obj(), .set(anahtar, deger), .push(deger),
  v["k"].asString() / .asInt() / .asBool() / .asArray().
  int64_t degerler dogrudan set edilebilir.
- Dosyanin basina neden-boyle aciklayan kisa bir yorum blogu koy.
- Dosya 300 satiri gecmesin.
