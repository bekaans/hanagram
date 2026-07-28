---
yaz: core/src/api/business.cpp
oku: core/tests/test_business.cpp, core/src/domain/business/appointment.hpp, core/src/domain/business/customer.hpp, core/src/kernel/runtime.hpp, core/src/api/messaging.cpp
dogrula: cmake --build core/build --target hanagram_tests 2>&1 && ./core/build/hanagram_tests
basari: TUMU GECTI
review: tools/review.sh
deneme: 8
---

`hg::kernel::registerBusinessApi(Runtime&)` fonksiyonunu yaz. Bu fonksiyon
runtime.hpp icinde bildirilmis, runtime.cpp icinden cagriliyor; govdesi eksik.

`core/src/api/messaging.cpp` ayni katmanda calisan hazir bir ornektir: dosya
duzenini, isimsiz namespace kullanimini, yardimci fonksiyon bicimini ve hata
donme seklini ORADAN al.

`core/tests/test_business.cpp` KABUL KAPISIDIR ve ayni zamanda tek sartnamedir:
metot adlari, yuk alanlari, hata kodlari, siralama ve yan etkiler orada yaziyor.
Once onu bastan sona oku. Test dosyasina DOKUNMA.

Kaydedilecek metotlar:
  business.setHours · business.hours
  appointment.slots · appointment.create · appointment.list · appointment.setStatus
  customer.create · customer.list · customer.update

Koleksiyonlar `hg::kernel::coll` icinde hazir:
  coll::kBusinessHours · coll::kAppointments · coll::kCustomers · coll::kUsers

Is kurallari domain katmanindadir; YENIDEN YAZMA, cagir:
  isValidSlot · slotTaken · freeSlots · slotsForDay · canTransition ·
  sanitizeNote · sanitizeService · normalizePhone · sanitizeName ·
  isValidEmail · normalizeTag · matchesQuery · foldForSearch · recordVisit

Kurallar:
- Yalnizca C++20 standart kutuphanesi. Ucuncu taraf bagimlilik yok.
- Zamani `ctx.clock.now()` ile al; sistem saatini dogrudan okuma.
- Kimlikleri `ctx.ids` ile uret.
- Sonuc sozlesmesi: basarida `json::ok(payload)`, hatada `json::fail(kod)`.
- Yetki: her metot `businessId` alanini dogrular. Baska bir isletmenin kaydi
  BULUNAMADI sayilir (varligini sizdirma).
- Derleyici uyarisi birakma. Bayraklar:
  -Wall -Wextra -Wpedantic -Wshadow -Wconversion
  Ozellikle -Wconversion: int64_t ile int/size_t arasinda ortuk donusum yapma,
  static_cast ile acikca donustur.
- Turkce karakterli DEGISKEN ADI kullanma; yorumlar Turkce olabilir.
- Dosya 400 satiri gecmesin. Gececek gibiyse yorumlari kisalt, kodu bolme.
