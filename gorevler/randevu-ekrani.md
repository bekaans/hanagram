---
yaz: app/lib/features/business/appointment_screen.dart, app/lib/features/business/appointment_sheet.dart
oku: app/lib/design/tokens.dart, app/lib/widgets/brand.dart, app/lib/core/ffi.dart, app/lib/core/app_state.dart, app/lib/features/business/business_screen.dart
dogrula: cd app && dart analyze lib
basari: No issues found
review: tools/review.sh
deneme: 6
---

Iki dosya yaz. Ikisi de HgTheme.of(context) disinda ham renk kodu KULLANMAZ,
intl paketi KULLANMAZ (tarih/saat elle bicimlendirilir), yeni bagimlilik eklemez.
Ikisi de 300 satiri GECMEZ — bu yuzden ikiye bolunuyorlar, tek dosyaya sigdirmaya
CALISMA.

Ikisi de cekirdege DOGRUDAN baglanir (yer tutucu DEGIL), `AppScope.of(context).core`
uzerinden. `core.call(...)` HATADA `CoreError` firlatir (ffi.dart'ta tanimli,
import et); her cagriyi try/catch ile sar, hata alinirsa kisa SnackBar goster,
ekran COKMEMELI.

bizId = `AppScope.of(context).session!.userId`.

═══════════════════════════════════════════════════════════════════
1) app/lib/features/business/appointment_screen.dart
═══════════════════════════════════════════════════════════════════

`AppointmentScreen` adinda StatefulWidget. Isletmenin gunluk randevu listesi.

Cekirdek metotlari:
  core.call('appointment.list', {'businessId': bizId, 'fromMs': int, 'toMs': int})
    -> {items: [{id,customerName,phone,service,note,at,priceKurus,status,source}]}
    status: "requested" | "confirmed" | "completed" | "cancelled"
  core.call('appointment.setStatus', {'businessId': bizId, 'appointmentId': String, 'status': String})

Yapmasi gerekenler:
- Ust barda gun secici: "< [Bugun / gunun tarihi] >" — ok butonlariyla gun
  degistirilir. Secili gun icin fromMs = o gunun herhangi bir anindan (ornegin
  secili DateTime'in gece yarisi UTC'si) hesapla, toMs = fromMs + 24 saat
  (Duration(hours: 24).inMilliseconds). Cekirdek kendi saat dilimine gore
  gunun sinirlarini zaten hesaplar; sen yalnizca o gun icine denk gelen genis
  bir aralik yollarsin.
- Liste: saate gore SIRALI (cekirdek zaten sirali doner), her satir bir KART:
  musteri adi, saat HH:mm (elle bicimlendir, DateTime.fromMillisecondsSinceEpoch),
  hizmet varsa alt satirda, durum rozeti (HgChip; renk requested=c.warning,
  confirmed=c.blue, completed=c.success, cancelled=c.textFaint).
  "requested" ise Onayla/Reddet butonlari (setStatus ile confirmed/cancelled).
  "confirmed" ise Tamamlandi/Iptal butonlari. Digerlerinde buton yok.
- Bos gun: EmptyState (brand.dart) — "Bu gun icin randevu yok".
- Yukleniyor: CircularProgressIndicator, state ile yonetilir.
- Sag altta FloatingActionButton: `showModalBottomSheet` ile
  `AppointmentSheet` acar (asagidaki dosyadan import et), businessId ve
  secili gunun dayMs'ini parametre olarak gecer; sheet basariyla randevu
  eklerse listeyi yeniden yukle (Navigator.pop sonrasi donen deger true ise).

═══════════════════════════════════════════════════════════════════
2) app/lib/features/business/appointment_sheet.dart
═══════════════════════════════════════════════════════════════════

`AppointmentSheet` adinda StatefulWidget. Constructor: `businessId` (String,
required) ve `dayMs` (int, required, o gunun herhangi bir ani). Yeni randevu
ekleme formu — bottom sheet icinde gosterilecek sekilde tasarlanir (SafeArea,
Padding, MediaQuery.viewInsets ile klavye acilinca kaymasi).

Cekirdek metotlari:
  core.call('appointment.slots', {'businessId': businessId, 'dayMs': dayMs})
    -> {slots: [int]}   (o gunun BOS slot baslangiclari, UTC ms, sirali)
  core.call('appointment.create', {
    'businessId': businessId, 'at': int, 'customerName': String,
    'phone': String?, 'service': String?, 'note': String?,
  })  -> basarili olursa yeni randevu nesnesi doner

Yapmasi gerekenler:
- Acilista appointment.slots cagrilir (initState, yukleniyor gostergesi).
- Bos slotlar yatay kaydirilabilir CHIP listesi (Wrap ya da yatay ListView),
  her chip saatini HH:mm gosterir, secili olan vurgulanir (renk c.violet).
  Hic bos slot yoksa "Bugun icin bos slot yok" mesaji, form devre disi.
- Musteri adi (TextField, ZORUNLU — bos ise "Ekle" devre disi kalir), telefon
  (TextField, istege bagli).
- "Ekle" butonu: slot secili ve ad doluysa aktif. Basilinca appointment.create
  cagrilir; basarili olursa `Navigator.of(context).pop(true)`; CoreError
  yakalanirsa SnackBar ile hata goster, sheet ACIK kalir (kullanici duzeltip
  tekrar denesin).

Dart analyze uyarisi birakma. Aciklama yazma disinda yorum satiri gerekmiyor.
