---
yaz: core/src/domain/business/customer.cpp
oku: core/src/domain/business/customer.hpp, core/src/util/json.hpp, core/tests/test_customer.cpp
dogrula: cmake --build core/build --target hanagram_tests 2>&1 && ./core/build/hanagram_tests
basari: TUMU GECTI
deneme: 5
---

`core/src/domain/business/customer.hpp` icindeki TUM fonksiyonlarin
govdesini yaz. Baslik dosyasi bir SOZLESMEDIR: imzalari, alan adlarini ve
davranis kurallarini degistirme.

Testler `core/tests/test_customer.cpp` icinde ve kabul kapisidir. Onlari da
oku; belirsiz kalan her davranisin dogru cevabi orada yaziyor. Test dosyasina
DOKUNMA.

Kurallar:
- Yalnizca C++20 standart kutuphanesi. Ucuncu taraf bagimlilik yok.
- Metin islemleri UTF-8 BAYT dizisi uzerinde yapilir. std::locale, <codecvt>
  ya da genis karakter (wchar_t) KULLANMA.
- Turkce harf katlamasi cok baytli bayt ciftleriyle yapilir; UTF-8 kodlari:
  C387=C  C3A7=c   C49E=G  C49F=g   C4B0=I  C4B1=i
  C396=O  C3B6=o   C59E=S  C59F=s   C39C=U  C3BC=u
  (sagdaki harf ASCII kucuk karsiligidir: c g i o s u)
- Tanimadigi cok baytli karakter oldugu gibi birakilir, atilmaz.
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
