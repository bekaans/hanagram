# Hanagram — Durum

Son güncelleme: 2026-07-28

> **Bu dosya projenin hafızasıdır.** Yeni oturumda okunacak tek dosya budur;
> kod tabanını baştan taramak yasaktır. Her görev bitiminde güncellenir.

---

## Ne inşa ediliyor

Sosyal medya iş platformu: insanların içerik üretip keşfedildiği ve aynı uygulamada
işini (müşteri, randevu, satış) yönettiği yer. Erken erişim, davet koduyla giriş.

Hedef platformlar: iOS · Android · tablet · Windows · macOS (+ web).

---

## Mimari özeti

```
app/ · admin/     Flutter — yalnızca sunum, karar vermez
    ↓ dart:ffi
core/include/     C ABI — tek dar sözleşme, sürümlü
    ↓
core/src/         C++20 — kernel · domain · algo
    ↓
depolama          dosya tabanlı (arayüz arkasında; SQLite/sunucu takılabilir)
```

- Bağımlılık oku **her zaman içe** bakar. Çekirdek hiçbir platformu bilmez.
- Çekirdek üçüncü taraf bağımlılık **içermez** (JSON dahil kendi kodumuz).
- Algoritma çekirdektedir: her platformda aynı sonucu üretir.
- Sunum katmanında iş kuralı yoktur; ekran gösterir ve sinyal gönderir.

---

## Kilitli sözleşmeler

| Dosya | Ne tanımlar | Kural |
|---|---|---|
| `core/include/hanagram/hanagram.h` | C ABI — dış dünyaya tek kapı | Kırıcı değişiklik MAJOR sürüm ister |
| `core/src/**/*.hpp` | Alan modelleri, motor arayüzleri | Yalnızca Claude değiştirir |
| `core/tests/*.cpp` | Davranış tanımı = kabul kapısı | Ajana asla yazdırılmaz |
| `app/lib/design/tokens.dart` | Renk, tipografi, boşluk | Ham renk kodu yasak |

---

## Kapılar

```
doğruluk : cmake --build core/build && ./core/build/hanagram_tests
           beklenen: "TUMU GECTI (217 senaryo)" · derleyici uyarısı sıfır
arayüz   : cd app && dart analyze lib        → "No issues found"
kalite   : tools/review.sh                    → "kalite: temiz"
```

---

## Tasarım Sistemi (genome referansı)

```
Renk:    c.text (ana), c.textMuted (ikincil), c.textFaint (zayıf)
Accent:  c.violet, c.blue, c.coral, c.warning, c.success
Surface: c.bg (sayfa), c.surface (kart), c.surfaceAlt (iç kart)
Border:  c.border (genel)
Tipografi:
  HgText.display  → 32px, w800, .SF Pro Text
  HgText.title    → 22px, w700
  HgText.heading  → 16px, w700
  HgText.body     → 14px, w400
  HgText.bodyStrong → 14px, w600
  HgText.caption  → 11px, w500
Boşluk:  HgSpace.xs(4), sm(8), md(12), lg(20), xl(28), xxl(40)
Radius:  HgRadius.sm(8), md(12), lg(16)
Bileşen: HgCard, HgChip, BrandButton, Avatar, HgFormField, BrandMark
Break:   HgBreak.isPhone(ctx), isTablet(ctx), isDesktop(ctx)
Ölçü:    HgText.scale(ctx, base), HgSpace.bottomPadding(ctx)=88(phone)/16(desk)
Kurallar:
  - Tüm text'te shadows: null (Liquid Glass'ta gölge yok, istisna: display/headline 3D shadow)
  - Ham renk kodu yasak (sadece HgTheme tokens)
  - const constructor zorunlu
  - Dart: analyze "No issues found" olmalı
  - Dosya boyutu: Dart <300 satır (borç: 300+ bölünmeli)
```

## Genome

### core/app_state.dart (220 satır)
Tür: InheritedNotifier<AppState>
AppScope.of(ctx) → AppState (session, discover, messages)
Session: {isPro, isCreator, userId, name, handle}
Model: User, MessageThread, AdItem, FeedItem

### core/ffi.dart (177 satır)
Tür: Bridge — dart:ffi ile C ABI köprüsü
hanagram.h → DynamicLibrary → fonksiyon imzaları
Senkron: core.call('api_name', json) → Map

### design/lib/src/ffi_stub.dart (47 satır)
Web stub — dart:ffi kullanılamaz, tüm FFI sınıfları boş/tanımsız.
HanagramCore: factory start → CoreUnavailable, call/callRaw → Map, version getter.
CoreUnavailable(detail), CoreError(code, hint) — native ffi.dart ile aynı API.

### core/utils.dart (70 satır)
fonksiyonlar: fmtCount(int)→String, relativeTime(DateTime)→String

### design/tokens.dart (311 satır)
HgColors, HgText, HgSpace, HgRadius, HgBreak, HgShadow
Tema: dark (c.bg=Color(0xFF0A0A0F), c.text=Color(0xFFF0F0F5))

### widgets/brand.dart (203 satır)
BrandMark(logo, animate), BrandWordmark(gradient yazı), BrandButton(gradyan buton)
Re-export: ui_components.dart (HgCard, Avatar, HgChip, EmptyState, HgTextField, HgFormField, HgButton)

### widgets/ui_components.dart (370 satır)
HgCard(child, padding, onTap, accent), Avatar(name, size, gradient, hasStory),
HgChip(label, color, icon, filled), EmptyState(icon, title, message, action),
HgTextField(hint, controller), HgFormField(label, controller), HgButton(label, onPressed)

### shell/app_shell.dart (288 satır)
AppShell → NavItem(profil, mesajlar, yönetim)
Alt bar: liquid glass, scroll'da gizlenir
Desktop: 3 sütun (SideRail + content)
ComposeSheet ayrı dosyada (compose_sheet.dart)

### shell/compose_sheet.dart (93 satır)
ComposeSheet → metin + konu seçimi + paylaş
8 konu kategorisi, gradient buton

### shell/shell_widgets.dart (162 satır)
SideRail(extended:false/76px, extended:true/232px)
RailItem(active durumunda violet vurgu)
Liquid glass arka plan + BackdropFilter

### shell/create_sheet.dart (84 satır)
CreateSheet → "Yakında" mesajı (Reels/Fikir/Hikaye rafa kaldırıldı)

### features/profile/profile_screen.dart (263 satır)
Orchestrator: LayoutBuilder(max 640px)
Hiyerarşi: Header → Stats → Actions → ServicesList → Directions → Reviews → Portfolio
isPro ise tüm bölümler gösterilir

### features/profile/widgets/profile_header.dart (86 satır)
ProfileHeader({name, handle, bio, isBusiness})
Avatar(100px, gradient) + sarı tik (checkmark_seal_fill) + isim + bio

### features/profile/widgets/profile_stats.dart (77 satır)
ProfileStats({onStatTap: ValueChanged<String>})
Row → 5 × Expanded(_StatCell)
StatData: satislar(1247), randevular(89), takipciler(2400), begeniler(5800), urunler(34), favoriler(342)
fmtCount ile formatlanmış, c.text rengi, tek satır simetrik

### features/profile/widgets/profile_actions.dart (62 satır)
ProfileActions({onAction: ValueChanged<String>})
Row(spaceEvenly) → 5 × _ActionBtn
Mesaj(chat_bubble), Ara(phone), Yol Tarifi(location), Randevu(calendar), Satın Al(cart)
52px daire, c.violet%0.10 arka plan

### features/profile/widgets/profile_services_list.dart (183 satır)
ProfileServicesList({c: HgColors})
Horizontal ListView → _ServiceColumn(160px genişliğinde)
3 kategori: Lazer Epilasyon, Cilt Bakımı, Saç Bakımı

### features/profile/widgets/profile_directions.dart (104 satır)
ProfileDirections({onOpenMaps, onShareLocation})
Adres + harita placeholder(120px) + "Yol Tarifi Al" butonu + paylaş

### features/profile/widgets/profile_reviews.dart (148 satır)
ProfileReviews({onAction: ValueChanged<String>})
Ortalama puan(4.8) + yıldızlar + yorum listesi + "Yorum Yap" butonu

### features/profile/widgets/stat_detail_sheet.dart (139 satır)
StatDetailSheet({statKey: String})
DraggableScrollableSheet → ListView.builder

### features/business/business_screen.dart (312 satır)
Yönetim başlığı + İstatistik(2) + İş Akışı(Görev Yönetimi) + Araçlar(5) + Paketler + Referanslar
Tüm araçlar ready: true (isCreator ayrımı kaldırıldı)

### features/business/task_screen.dart (630+ satır)
Görev yönetimi ekranı — arama + görev listesi + çalışanlar
Arama: çalışan adına göre tüm görevleri listeler (yeni→eski)
Modeller: TaskItem (models/task_item.dart) + Worker (widgets/task_models.dart)
Widget'lar: TaskTabBtn, MiniStat, TaskCard, WorkerCard (widgets/task_widgets.dart)

### features/business/appointment_screen.dart (400+ satır)
Randevu yönetimi — arama + takvim + randevu listesi
Arama: müşteri adına göre tüm randevular (tarih, saat, onay durumu)
Gün seçildiğinde o günün randevuları gösterilir

### features/business/accounting_screen.dart (727 satır)
Muhasebe ekranı — gelir/gider/kâr, aylık rapor, karşılaştırma, istatistikler
Supabase AccountingService ile çalışır

### features/business/widgets/task_models.dart (28 satır)
Worker({name, role, status, avatar}) + sampleWorkers (3 çalışan)

### features/business/widgets/task_widgets.dart (241 satır)
TaskTabBtn, MiniStat, TaskCard(TaskItem, priority renk), WorkerCard(gradient avatar)

### features/business/models/task_item.dart (64 satır)
TaskItem({id, title, time, priority, isDone, assignee})
TaskPriority enum: low, medium, high
sampleTasks: 4 örnek görev

### features/business/appointment_screen.dart (181 satır)
Randevu listesi + takvim header + randevu ekleme/düzenleme

### features/business/customer_screen.dart (161 satır)
CRM — müşteri portföyü listesi

### features/business/product_screen.dart (169 satır)
Ürün kataloğu + fiyat yönetimi

### features/business/sale_screen.dart (122 satır)
Satış ve ciro — gelir/gider raporları

### features/business/media_screen.dart (305 satır)
Fotoğraf ve video yönetimi galerisi

### features/messages/messages_screen.dart (411 satır)
Story'ler(üst) + sohbet listesi(alt) + arama + yeni mesaj

### features/messages/chat_detail_screen.dart (307 satır)
Tek sohbet ekranı — mesaj listesi + gönderme

### features/discover/discover_screen.dart (257 satır)
TikTok tarzı dikey tam ekran video akışı — orchestrator
Widget'lar: discover_widgets.dart (FullPageTile, SideAction, TrendingChip)

### features/discover/discover_widgets.dart (218 satır)
FullPageTile(gradient arka plan, yazar bilgisi, konular)
SideAction(sağ taraftaki eylem butonları), TrendingChip(konu filtresi)

### features/feed/feed_screen.dart (217 satır)
Instagram tarzı dikey post akışı + GlassTopBar
Modeller: FeedItem (app_state.dart), _sampleFeed (6 örnek)
Widget'lar: feed_widgets.dart (PostCard, _GlassHashtag, _Action)

### features/feed/feed_widgets.dart (269 satır)
PostCard(FeedItem, glass arka plan, liked/saved state, dwell tracking)
_GlassHashtag(blur efekti, owner kontrolü), _Action(ikon + label)

### features/onboarding/invite_gate.dart (627 satır)
Orchestrator — kayıt/giriş kapısı, tüm state burada, formlar callback'lerle bağlı
Login + Register modu, rate limiting, OTP, hesap oluşturma

### features/onboarding/login_form.dart (218 satır)
LoginForm — giriş formu UI bileşeni (pure widget, state yok)
TextField'lar, hata kutusu, kilit kutusu, giriş/kayıt geçiş butonları

### features/onboarding/register_form.dart (487 satır)
RegisterForm — 3 adımlı kayıt UI bileşeni (pure widget, state yok)
RegisterStep enum (code/contact/identity), adım bazlı animasyonlu geçiş
Code step: kod doğrulama, referans bilgisi
Contact step: eposta/telefon toggle, OTP, kullanıcı adı
Identity step: profil resmi, ad soyad, hesap türü

### features/onboarding/widgets/invite_widgets.dart (270 satır)
inviteErrorText(kod→Türkçe mesaj), MembershipRow, InviteCodeField,
InviteTextField, AccountPicker(3 seçenek), FirstRunCodes, InviteBackdrop

### features/onboarding/update_screen.dart (361 satır)
Güncelleme ekranı — platform bazlı bilgi notları
Zorunlu güncelleme: "Sonra" butonu gizli, kapatılamaz (PopScope)
Opsiyonel: "Sonra" → SystemNavigator.pop(), "Güncelle" → launchUrl

### features/onboarding/whats_new_screen.dart (221 satır)
Yeni sürüm özeti — her güncellemeden sonra bir kez gösterilir
SharedPreferences'da son görülen versiyon saklanır
Renkli madde işaretleri (+ yeşil, ! sarı, varsayılan mavi)
onDismiss callback ile kapanır

### features/onboarding/video_splash.dart (107 satır)
Açılış logo animasyonu — BrandMark animasyonlu

### features/settings/settings_screen.dart (430+ satır)
Kullanıcı tercihleri — tema, bildirim, gizlilik, çıkış
+ Doğrulama bölümü (işletme/kişisel)
+ Çıkış: SharedPreferences.clear() ile tüm verileri siler
Widget'lar: settings_widgets.dart (SettingsSection, ThemePicker, SettingsToggleTile, SettingsInfoTile)

### features/settings/verification_sheet.dart (300+ satır)
Doğrulama form sayfası — TC no (11 hane checksum), vergi no, dosya boyut/MIME kontrol
guvenli-kod: 5MB limit, JPG/PNG/WEBP, input validation, error handling

### core/supabase_service.dart (37 satır)
Supabase bağlantısı + client erişimi. init(), session, user.

### core/referral_service.dart (~200 satır)
Referans kodu: verifyCode, redeemCode, isUsernameAvailable, createProfile

### core/media_service.dart (~100 satır)
Medya yükleme: uploadAvatar, uploadMedia, getPublicUrl

### core/update_service.dart (80+ satır)
Otomatik güncelleme: 5 platform (android/ios/macos/windows/web)
checkForUpdate() → UpdateInfo

### core/verification_service.dart (367 satır)
Doğrulama + takipçi servisi: submitPersonal/Business, follow/unfollow, isFollowing, getFollowerCount, isInBusinessGroup

### core/profile_service.dart (~150 satır)
Profil istatistikleri: getProfileStats, setDisplayStat, updateAddress

### core/accounting_service.dart (~200 satır)
Muhasebe: getMonthlyReport, addTransaction, getStats

### core/connection_service.dart (~100 satır)
Bağlantılar: getMyConnections, sendRequest, acceptRequest

### core/notification_service.dart (~80 satır)
Push bildirim: init(), sendToUser(targetUserId, title, body, data)
Fcm token yönetimi, topic aboneliği

### core/appointment_reminder.dart (~200 satır)
Randevu hatırlatma + onay/red bildirim sistemi
sendReminders() → yarınki pending randevulara hatırlatıcı gönder
confirmAppointment(id) → onayla + karşı tarafa bildir
cancelAppointment(id) → iptal et + karşı tarafa bildir
AuthZ kontrolü: sadece katılımcı veya oluşturan işlem yapabilir

### core/web_compat.dart (9 satır)
Koşullu export hub — native'de dart:io, web'de stub.
Tüm dosyalar `import 'web_compat.dart'` yapmalı, dart:io'yu doğrudan import etmemeli.

### core/web_compat_native.dart (17 satır)
Native platform: dart:io File export + PlatformDetect (android/ios/macos/windows).

### core/web_compat_web.dart (18 satır)
Web stub: File (boş), PlatformDetect → 'web'.

### core/web_compat_file.dart (9 satır)
Koşullu export hub — native'de dart:io File, web'de stub File.

### core/web_compat_file_native.dart (9 satır)
Native: dart:io File export + pathSeparator const.

### core/web_compat_file_web.dart (45 satır)
Web File stub: path, existsSync, readAsBytes (→Uint8List), stat, statSync, writeAsBytes.

### core/platform_image.dart (7 satır)
Koşullu export hub — native'de dart:io File ile, web'de placeholder.

### core/platform_image_native.dart (38 satır)
Native: Image.file(file) widget'ı — dart:io File parametre alır.

### core/platform_image_web.dart (33 satır)
Web: placeholder Container — Image.file compile edilemez, basit ikon gösterir.

### features/settings/settings_widgets.dart (243 satır)
SettingsSection(bölüm kabı), SettingsGlassCard(cam kart)
ThemePicker(3 tema seçeneği), ThemeOption(bireysel tema butonu)
SettingsToggleTile(açma-kapama), SettingsInfoTile(bilgi satırı)

### admin/lib/main.dart (195 satır)
Orchestrator — AdminApp + AdminHome state + login/rail/tab yönlendirme
Widget'lar: widgets/ (admin_login, admin_rail, overview_tab, users_tab, updates_tab)
3 sekme: Genel Bakış, Kullanıcılar, Güncellemeler

### admin/lib/core/admin_supabase.dart (281 satır)
AdminSupabase — Supabase bağlantısı + veri çekme (fetchOverview, fetchUsers, fetchVersions, fetchUserDetail)

### admin/lib/widgets/admin_login.dart (134 satır)
AdminLoginScreen — eposta+şifre girişi, BrandMark, hata gösterimi

### admin/lib/widgets/admin_rail.dart (100 satır)
AdminRail — sol kenar navigasyon (3 sekme + yenile + çıkış butonu)

### admin/lib/widgets/overview_tab.dart (152 satır)
OverviewTab — genel bakış: 8 istatistik kartı + algoritma durumu

### admin/lib/widgets/users_tab.dart (553 satır)
UsersTab — kullanıcı listesi + detay (ilgi profili, mesajlar, gönderiler)

### admin/lib/widgets/updates_tab.dart (379 satır)
UpdatesTab — versiyon yönetimi, changelog, zorunlu güncelleme toggle'ı
```

### tools/bump_version.sh
Otomatik versiyon artırma: pubspec.yaml + iOS Info.plist + Android build.gradle + SQL migration
Kullanım: `./tools/bump_version.sh [major|minor|patch] [changelog] [is_force]`

## Adımlar

| # | İş | Kim | Durum |
|---|---|---|---|
| 01 | C++ çekirdek: kernel, depo, olay veriyolu, kimlik, zaman | Claude | ✅ |
| 02 | Öneri + öğrenme motoru (ilgi · skorlama · keşif · kalibrasyon) | Claude | ✅ |
| 03 | Davet/referans sistemi + erken erişim | Claude | ✅ |
| 04 | C ABI + Dart FFI köprüsü | Claude | ✅ |
| 05 | Mesajlaşma çekirdeği | Claude | ✅ |
| 06 | Tasarım sistemi + marka | Claude | ✅ |
| 07 | Uygulama: davet kapısı, akış, keşfet, profil, panel | Claude | ✅ |
| 08 | Admin paneli: kullanıcılar, mesajlar, davet ağacı, algoritma | Claude | ✅ |
| 09 | Mesajlaşma arayüzü | DeepSeek | ✅ 2. denemede |
| 10 | Randevu + CRM çekirdeği | Claude + DeepSeek | ✅ |
| 11 | Randevu ekranı | DeepSeek + Claude | ✅ |
| 12 | CRM ekranı | DeepSeek + Claude | ✅ (entegrasyon + hata düzeltmesi) |
| 13 | Ürün + satış + finans çekirdeği | Claude | ✅ (product.hpp/cpp, sale.hpp/cpp, 6 API, 22 yeni test) |
| 14 | İşletme paneli ekranları | Claude | ✅ (ürün, satış, finans ekranları + business_screen entegrasyonu) |
| 15 | Mesajlaşma arayüzünü çekirdeğe bağla | Claude | ✅ (message.threads API'ye bağlandı) |
| 16 | Reklam sistemi arayüzü (ad_screen, ad_item, ad_sheet + entegrasyon) | Claude | ✅ |
| 17 | Platform derleme hattı (build-core.sh, 5 platform) | Claude | ✅ |
| 18 | Medya: fotoğraf/video ekleme ve gösterim | Claude | ✅ (media.hpp/cpp, 3 API, 9 test, Flutter galeri + image_picker) |

---

## Teknik borç (dondurulmuş)

`tools/.review-muafiyet` içinde kayıtlı. Kapı **yeni** ihlali engeller, eskisi
ayrı ayrı ödenir.

| Dosya | Satır | Not |
|---|---|---|
| `app/lib/widgets/brand.dart` | 203 | ×2 (admin kopyası) — ortak pakete taşınmalı |

**Not:** Dosya boyutu sınırı dile göre ayrıldı — Dart 300, C++ 400. 300 satır bir
arayüz dosyasının ölçüsüdür; tek başlığın sözleşmesini karşılayan bir C++ dosyasını
mekanik ikiye bölmek okunurluğu artırmaz. Bu değişiklikle `ranker.cpp` (346),
`social.cpp` (331) ve `json.cpp` (344) borç listesinden çıktı.

**Ayrıca:** `app/` ve `admin/` arasında `brand.dart` + `tokens.dart` kopyalanmış
durumda. Ortak bir pakete taşınmalı — iki kopya er geç ayrışır.

---

## Bilinen tuzaklar

| Yaşanan | Önlem |
|---|---|
| Davet kodlarında `O`, `I`, `L` yok; `normalizeCode` bunları rakama çevirir | Test verisinde bu harfleri kullanma |
| Kimlik üreteci monoton değildi — aynı ms'de sıra bozuluyordu | Düzeltildi; kimliğe göre sıralama artık zaman sırası verir |
| Aynı ms'de iki sohbete mesaj → `lastAt` eşit, liste sırası belirsiz | `lastMessageId` ikincil anahtar olarak eklendi |
| Ajan Türkçe karakterli değişken adı yazıyor (`gün`) | Göreve "tanımlayıcılar İngilizce" kuralını yaz |
| Ücretsiz modellerin dakikalık token kotası 8-12k | Görev başına tek dosya; ya da ucuz ücretli katman (~3 kuruş/ekran) |
| `dart analyze` tüm projeyi tarar; eski uyarı yeni görevi bloklar | Projeyi temiz tut, uyarı biriktirme |
| Admin token'ı uygulama kodunda sabit (`hanagram-erken-erisim`) | Üretime çıkmadan önce yapılandırmaya taşınmalı |
| Testte `const auto& x = rt.call(...)["data"]["items"].asArray();` — geçici nesne ifade sonunda ölür, referans sarkar | Sonucu önce adlandırılmış `json::Value`'ya al. 8 testi bozmuş, ajanı 20+ deneme boyunca haksız yere kalmış gösterdi |
| Boş diziye `[0]` ile erişen test çöker; çökme sonraki tüm çıktıyı yutar | Testte sınır güvenli `at(dizi, i)` kullan |
| DeepSeek V4 Pro akıl yürütme modeli: çıkışın tamamını düşünmeye harcayıp kod yazmadan kesilebilir | Ajan ayarında `extra.reasoning.max_tokens` sınırla, `max_tokens` artır |
| Çekirdek `localtime` çağırırsa test makinenin saat dilimine bağlanır | Zaman UTC ms; saat dilimi veriden gelir (`WorkingHours.tzOffsetMinutes`) |
| Ajan `core.call()`'ı `Future` sanıp `await` koyar (aslında senkron, `Map` döner) | Görev dosyasında imzayı ACIKÇA "senkron, await KOYMA" diye yaz |
| Ajan aynı hatada 3+ kez takılıp kendini düzeltemez | 5 denemede kapı geçmediyse Claude devralır — `.son` dosyasını okuyup tek satırı elle düzeltmek, tekrar tekrar tüm dosyayı yazdırmaktan ucuz |
| Flash bazen kod yerine görünür metinde "nasıl kısaltırım" diye kendi kendine tartışır, bütçe kod yazmadan biter | Dosya boyutu sınırını görevi BÖLEREK karşıla, ajana "kısalt" deme |

---

## Sprint geçmişi

| Turn | Ne yapıldı | Input (~) | Output (~) | Oran | Süre |
|---|---|---|---|---|---|
| 1 | dart analyze temizliği (21→0 uyarı) | 50K | 2K | 25:1 | 3d |
| 2 | Genome yazımı (DURUM.md) | 15K | 5K | 3:1 | 2d |
| 3 | Tech debt: 5 dosya bölündü (577+557+463+387+367→288+229+288+203+217) | 120K | 25K | 4.8:1 | 1d |
| 4 | Tech debt: discover+settings bölündü (473+463→257+218+232+243) | 60K | 12K | 5:1 | 1d |
| 5 | Tech debt: admin main.dart bölündü (779→178+73+87+98+285+153+81) | 50K | 15K | 3.3:1 | 1d |
| 6 | Web build tamamlandı: web_compat + PlatformImage + ffi_stub web bridge | 80K | 5K | 16:1 | 1d |

## ⚠️ Backend entegrasyon durumu (keşif: 2026-07-29 — Kaan'ın "çalışmıyor" bildirimi üzerine)

**Görev:** Arkadram (`/Users/bekaans/vscode/han-medya-is-takibi`, bkz. `~/Desktop/Yazılım/ARKADRAM_DEVIR.md`) backend'i
Hanagram'a komple aktarılacaktı, sadece Flutter frontend aynı kalacaktı. Başka bir ajan bunu denedi, sonuç **çalışmıyor**.
Tam keşif + gerçek `dart analyze` + gerçek `cmake --build` + Explore ajanı ile doğrulandı. Özet:

- **C++ çekirdek** (`core/`): temiz derleniyor, **217/217 test geçiyor**. Sorun burada DEĞİL.
- **`dart analyze lib`**: önceki "temiz" iddiası YANLIŞ çıktı — `.dart_tool` hiç oluşmamıştı (pub get eksikti).
  Gerçek sonuç: **5 hata**, hepsi `core/onesignal_native.dart`'ın kaldırılmış `onesignal_flutter` paketini
  import etmeye devam etmesinden (ölü dosya, OneSignal temizliği yarım kalmış — `onesignal_compat.dart`,
  `onesignal_native.dart`, `onesignal_web.dart` hiçbir yerden import edilmiyor, silinebilir).
- **Kök sebep (asıl kırılma)**: Supabase'e taşınan servisler (`task_service`, `crm_service`, `connection_service`,
  `accounting_service`, `message_service`, `appointment_reminder`, admin panel) sistematik olarak
  `SupabaseService.user?.id` (= `auth.uid()`) değerini, şemanın FK'lerinin gerçekte istediği `users.id` (ayrı,
  `users.auth_id` üzerinden eşlenen UUID) yerine kullanıyor. Sonuç: her INSERT FK ihlaliyle sessizce başarısız,
  her SELECT yanlış id ile filtrelendiği için boş dönüyor — hepsi geniş `catch (_) {}` bloklarıyla yutuluyor,
  hiçbir yerde hata görünmüyor. Doğru yapan örnek zaten var: `profile_service.dart`, `verification_service.dart`
  (`auth_id → users.id` çözümü net biçimde yapılıyor) — düzeltme bu deseni tüm bozuk servislere uygulamak.
- **Hiç Supabase'e taşınmamış özellikler** (feed, discover, customer/product/sale/media/ad ekranları): hâlâ yerel
  C++ FFI çekirdeğine bağlı. Ama gerçek kullanıcılar Supabase Auth ile kayıt oluyor ve yerel çekirdeğin kullanıcı
  deposuna HİÇ yazılmıyor → her FFI çağrısı `ERR_USER_NOT_FOUND` veriyor → birçok ekran bu hatayı yutup sahte
  örnek veri gösteriyor (bu davranış projenin kendi ilkesiyle çelişiyor: `main.dart:274` "sahte veriye düşülmez").
  Teams, public portfolio, reviews, ad-packages, business referral ekranlarının ise hiçbir backend'i yok —
  sadece bellek içi sabit liste (yeniden başlatınca kaybolur).
- **Çift/çelişkili şema**: `app/supabase/migrations/*` ve `supabase/migrations/*` diye BİRBİRİNDEN BAĞIMSIZ iki ayrı
  "full schema" seti var (bazı tetikleyiciler iki yerde de tanımlı) — hangisinin gerçek projeye uygulandığı repodan
  belli değil, `supabase/config.toml` yok.
- **Platform çapraz derleme**: sadece macOS'ta native çekirdek gerçekten derlenip bağlanmış
  (`core/build-macos/libhanagram.dylib` → `app/macos/Runner/`). Android/iOS/Windows'ta CMake/Xcode/Gradle
  tarafında çekirdeği üretip bağlayan HİÇBİR yapı yok — bu üç platformda uygulama "Çekirdek yüklenemedi" ekranında
  kilitli kalır, girişe bile ulaşamaz. Web sadece stub hiç atmadığı için görünüşte ayakta kalıyor.

**Faz 0 + Faz 1 UYGULANDI (2026-07-29, Kaan onayıyla — "arkadram'ı komple aktar, tüm yetki sende"):**
- Ölü OneSignal dosyaları silindi (`onesignal_compat/native/web.dart`) — `dart analyze` artık gerçekten temiz.
- `SupabaseService.myDbId()` eklendi (auth_id→users.id çözümü, session boyunca cache'li) + `clearCache()`
  (her iki çıkış noktasına bağlandı: settings_screen.dart, invite_gate.dart).
- Sistemik id hatası düzeltildi: `task_service.dart` (createTask/getMyTasks/getTasksForDate/createAppointment/
  getAppointmentsForDate/searchAppointments/searchTasksByAssignee/canTagUser/getMyConnections),
  `connection_service.dart` (sendRequest/getPendingRequests/getMyConnections), `accounting_service.dart`
  (4 metod, toplu), `message_service.dart` (findOrCreateDm/getThreads/getMessages/sendMessage/markAsRead/
  subscribeToMessages/subscribeToThreads/getConnections — searchUsers'daki tek doğru kullanım korundu),
  `crm_service.dart` (tüm metodlar, toplu), `appointment_reminder.dart` (sendReminders/confirmAppointment/
  cancelAppointment + iç `auth_id`→`id` düzeltmesi), admin `admin_supabase.dart` (`fetchUserDetail`).
- Ekstra bulunan bağımsız hatalar da düzeltildi: `connections_screen.dart` `u['auth_id']` okuyordu ama
  `ConnectionService.searchUsers` o alanı hiç seçmiyordu (`u['id']` olmalıydı — bağlantı isteği göndermek
  HİÇ çalışmıyordu, id her zaman boş string'di); `task_service.dart searchTasksByAssignee` `auth_id` seçip
  `created_by/assigned_to` (dbId kolonları) ile karşılaştırıyordu; `canTagUser` parametresi `targetAuthId`
  adındaydı ama tek çağıran yer (`createTask`) zaten dbId veriyordu — parametre `targetUserId`'ye çevrildi.
- Doğrulama: `dart analyze lib` (app + admin) → **0 sorun**. `flutter build web --release` → **başarılı**.
  C++ çekirdek dokunulmadı, 217/217 test hâlâ geçiyor.
- **🔴 KRİTİK EK BULGU — aynı hata RLS (Row Level Security) katmanında da var:** Dart tarafı düzeltilse bile
  veritabanı politikaları `auth.uid()`'i doğrudan `users.id` tipindeki kolonlarla (`user_id`, `owner_id`,
  `created_by`, `sender_id`) karşılaştırıyordu — `connections`, `business_groups`, `group_members`,
  `conversations`, `conversation_members`, `messages` tablolarının TAMAMINDA. İkinci şema setinde
  (`supabase/migrations/20260729_full_schema.sql`) ise `tasks`/`appointments`/`crm_entries`/`connections`/`media`
  politikaları `USING (true)` yani TAMAMEN AÇIKTI — hangi set canlıda aktifse, ya her şey RLS'te sessizce
  reddediliyordu ya da (açık ihtimalinde) **herkes herkesin CRM/görev/randevu kaydını görebiliyordu**
  (guvenli-kod ihlali, Kaan'ın kendi CRM-gizliliği talebiyle doğrudan çelişiyor). Hangi set gerçekten canlı
  bilinmiyor (repoda `supabase/config.toml` yok) — bu yüzden düzeltme dosyası ikisinden de BAĞIMSIZ, idempotent
  yazıldı: `supabase/migrations/20260730_fix_rls_id_mismatch_and_new_tables.sql`. **Kaan'ın yapması gereken
  TEK iş: bu dosyayı Supabase SQL Editor'da çalıştırmak** (CLI linkli değil, `service_role` key yok — buradan
  otomatik uygulanamıyor). Aynı dosya Faz 2'nin eksik tablolarını da ekliyor (aşağıya bak).
- **Bilinçli KAPSAM DIŞI bırakıldı:** push bildirim transportu (`send-notification` edge function hâlâ
  OneSignal'e gönderiyor ama client SDK'sı tamamen kaldırılmış — hiçbir cihaz artık kayıtlı değil, bildirim
  gönderimi sessizce hiçbir yere gitmiyor). Bu ayrı bir karar gerektiriyor (OneSignal'i native'e uygun şekilde
  geri getir ya da Supabase-native bildirim tablosuna geç) — CRUD akışlarını bloklamıyor (fire-and-forget),
  bilerek ayrı faza bırakıldı.
- **Gerçek cihaz/tarayıcıda uçtan uca test edilmedi** (login → görev/randevu/CRM/mesaj oluştur → başka
  hesapla doğrula) — statik analiz + derleme doğrulaması yapıldı, Kaan'ın canlı Supabase projesine karşı
  gerçek kullanıcı akışı testi hâlâ gerekiyor.

**Faz 2 devam ediyor (2026-07-29, aynı oturum):** Migration dosyasına `customers` tablosu (kişi kartı: ad/telefon/
e-posta/not/etiket, telefonla dedup UNIQUE INDEX) + `crm_entries`'e `customer_id/payment_method/source/line_items`
kolonları + `products`'a `category/updated_at` eklendi. Yeni servisler: `core/customer_service.dart`,
`core/product_service.dart`, `CrmService.createSale/getSales`. Ekranlar Supabase'e bağlandı (yerel FFI + sahte
veri fallback'i kaldırıldı, frontend widget'lara dokunulmadı): `customer_screen/sheet.dart`, `product_screen/
sheet.dart`, `sale_screen/sheet.dart`. Doğrulama: `dart analyze lib` → 0 sorun.
**Faz 2 devamı (aynı oturum, devam):** `media_service.dart`'a DB CRUD eklendi (`listMedia/registerMedia/
deleteMediaRecord`) — `media_screen.dart` artık gerçekten Supabase Storage'a yüklüyor + `media` tablosuna
kaydediyor (önceden sadece yerel path saklanıyordu, hiçbir yere yüklenmiyordu). `MediaThumb`/`_MediaViewer`
artık `http` URL'leri `Image.network` ile gösteriyor (yerel `PlatformImage` fallback olarak kaldı).
`review_service.dart` eklendi (`reviews` tablosu — gerçek kullanıcı yorumu VEYA işletmenin uygulama dışı aldığı
yorumu elle girmesi, `reviewer_id` NULL olabilir). `reviews_screen.dart` gerçek veriye bağlandı.
`post_service.dart` eklendi (posts/post_likes/post_comments — beğeni/yorum sayıları PostgREST aggregate yerine
istemci tarafında sayılıyor, sürüm bağımsız daha güvenilir). `portfolio_screen.dart` gerçek portfolyo
gönderilerine bağlandı, gerçek görsel gösteriyor (önceden hep gradient placeholder'dı).
Tüm bu adımlarda `dart analyze lib` → 0 sorun.

**KOMPLE BİTTİ (2026-07-29, Kaan: "komple bitir önce sonra çalıştıralım"):**

- **Ekip (`team_screen/team_detail_screen/team_sheet.dart`)**: `TeamService` eklendi. Ekip kur, gerçek
  kullanıcı arayıp davet et (eski hali sadece isim yazdırıyordu, hiçbir hesaba bağlanmıyordu — düzeltildi),
  gerçek ekip sohbeti (`conversations.team_id` yeni kolon + `MessageService.findOrCreateTeamConversation`,
  mevcut `ChatDetailScreen` yeniden kullanıldı), paylaşımlı görevler (`tasks.group_id`) ve paylaşımlı CRM
  (`crm_entries.group_id` yeni kolon + RLS) gerçek tablolardan okunuyor.
- **Feed/Keşfet**: `feed_service.dart` tamamen yeniden yazıldı — artık C++ çekirdek yerine
  `post_service.dart` (Supabase) kullanıyor, `AppState.boot()` çekirdeksiz de çalışıyor (aşağıya bak). Sahte
  6 örnek gönderi kaldırıldı, boş durumda dürüst EmptyState gösteriliyor. Beğeni artık gerçekten kalıcı
  (`post_likes` tablosu, iki yönlü toggle — eskisi sadece tek yönlü sahte sayaç arttırıyordu).
- **🔴 Ek kritik bulgu + düzeltme — profil görüntüleme tamamen kırıktı:** `profile_screen.dart` başkasının
  profiline gidince (`isOwnProfile:false`) hâlâ `app.session` (KENDİ verin) gösteriyordu — `widget.userId`
  hiç kullanılmıyordu. Ayrıca `ProfileService.getProfileStats`/`VerificationService.isVerified` çağrılarına
  yanlışlıkla dbId veriliyordu (auth_id bekliyorlar) — istatistikler ve doğrulama rozeti HERKES için sessizce
  boş/yanlış dönüyordu. "Mesaj" butonu başka birinin profilinde `'dm_${widget.userId}'` diye SAHTE bir sohbet
  id'si üretiyordu (gerçek konuşma değil). Profil içindeki portfolyo bölümü tamamen sahte gradient+sayı idi.
  Hepsi düzeltildi: `ProfileService.getPublicProfile(handle)` eklendi, ekran artık kendi/başkası ayrımını
  doğru veriyle çözüyor, Yorumlar sekmesi başkasının profilinde de görünüyor ("Yorum Yap" sadece başkasının
  profilinde, kendi profilinde değil), mesaj butonu `MessageService.findOrCreateDm` ile gerçek sohbet açıyor,
  portfolyo gerçek `posts` verisiyle geliyor.
- **`profile_reviews.dart` "Yorum Yap"**: gerçek veriye bağlandı, `ReviewService.submitReview` ile çalışıyor.
- **🔴 Faz 4 — çapraz platform çözüldü:** `AppState.boot()` artık çekirdek yüklenemezse (Android/iOS/Windows'ta
  native lib yok) uygulamayı BLOKLAMIYOR — sadece eski, zaten kullanılmayan davet/yerel-öneri akışını
  (`inviteService`) devre dışı bırakıyor. Auth/mesaj/randevu/görev/CRM/ekip/akış hepsi Supabase'den geldiği
  için artık gerçekten her platformda açılışa kadar çalışır (native derleme ayrı bir konu — core hâlâ sadece
  macOS'ta derlenmiş durumda, ama artık ZORUNLU değil).
- **`.env.example`** eklendi (`app/`, `admin/`) — `.gitignore` zaten `.env*`'i kapsıyordu. Not: Supabase
  "publishable" anahtarı zaten public/istemci-taraflı olacak şekilde tasarlanmış (asıl güvenlik RLS'te) —
  hardcoded default'un kalması ciddi bir açık değil, ama env override artık dokümante edilmiş durumda.
- Doğrulama: `dart analyze` (app+admin) → **0 sorun**. `flutter build web --release` → **başarılı**.
  `flutter build macos --debug` → **başarılı** (native çekirdek yüklü platformda da regresyon yok).

**Ek temizlik (aynı geçiş):** `appointment_screen.dart` ve `accounting_screen.dart`'ta da customer/product/
sale'dekiyle AYNI sahte-veri-fallback deseni bulundu (servisler zaten hiç exception fırlatmadığı için bu
catch blokları ölü kodmuş, ama yine de temizlendi — `_sampleAppointments`/`_sampleCurrentReport`/
`_samplePreviousReport`/`_sampleEntries` silindi). `review_model.dart`'taki artık kullanılmayan
`sampleReviews`/`averageRating` de silindi.

**Admin paneli komple yenilendi (2026-07-30 gece, Kaan uyurken — "tam yetki sende, programı tamamla"):**
- Giriş: kullanıcı adı `admin` / şifre `Yenisifre.54` — Supabase Auth hesabı gerçekten oluşturuldu
  (e-posta `bekaans+hanagramadmin@icloud.com` — Kaan'ın gerçek kutusuna düşer, + adresleme). **Kaan'ın yapması
  gereken 2 şey:** (1) o e-postadaki Supabase onay linkine tıkla, (2) `supabase/migrations/
  20260731_admin_bypass_and_email_confirm.sql` dosyasını SQL Editor'da çalıştır. İkisi de yapılmadan admin
  girişi başarısız olur ("Hesap henüz onaylanmamış").
- **🔴 Kritik bulgu**: admin paneli normal uygulamayla AYNI RLS altında çalışıyordu — yani admin hesabı bile
  hiç kimsenin görev/randevu/CRM/mesaj/bağlantı kaydını göremiyordu (Faz 1'in "sadece kendi verin" düzeltmesi
  admin'i de kapsıyordu). Yeni migration `users.is_admin` + `is_admin()` SQL fonksiyonu ekleyip ilgili tüm
  SELECT politikalarına "ya da admin isen" şartını ekledi.
- **Yeni özellik — kullanıcı arayıp tüm bilgisine + konuşmalarına erişme**: `AdminSupabase.fetchUserConversations`/
  `fetchConversationMessages` eklendi, Kullanıcılar sekmesinde her kullanıcının Sohbetler bölümü tıklanınca
  mesajlar salt-okunur açılıyor (moderasyon amaçlı).
- **Referans kodu profilde**: her kullanıcının detay sayfasında, profil resminin altında referans kodu +
  kaç kişi getirdiği + davet ettikleri listesi (ayrıca ayrı "Referanslar" sekmesi de duruyor, orada tüm
  kullanıcılar arasında arama yapılabiliyor).
- **Yeni sekme: Doğrulamalar** — kişisel/işletme doğrulama isteklerini listeler, belge görsellerini gösterir,
  tek tıkla onay/red (onaylanınca kullanıcı otomatik `verified=true` olur). Daha önce DURUM.md'de "sıradaki iş"
  olarak bekliyordu, şimdi var.
- Doğrulama: `dart analyze` (admin) → 0 sorun, `flutter build web --release` → başarılı, giriş ekranı
  tarayıcıda görsel olarak doğrulandı (yeni "Kullanıcı adı" etiketiyle).

**Bilerek dışarıda bırakılan (kapsam dışı, dürüst durumda kaldılar):**
- `ad_screen.dart` (zaten sahte veriye düşmeden gerçek hata veriyor), `packages_screen.dart`,
  `referral_screen.dart` (business) — Kaan'ın orijinal Arkadram spesifikasyonunda hiç yok, ikisi de
  "yakında" diyor, yanlış bir şey iddia etmiyor.
- `features/profile/widgets/stat_detail_sheet.dart` — profildeki bir istatistiğe (satış/randevu/takipçi/
  beğeni/ürün/favori) tıklayınca açılan detay listesi hâlâ 6 kategoride sabit sahte veri. Ana sayıların
  kendisi zaten gerçek (`ProfileStats`/`ProfileService.getProfileStats` üzerinden) — sadece tıklayınca açılan
  DETAY listesi sahte. Gerçek yapmak takipçi-listesi sorgusu (yok) ve favoriler tablosu (hiç yok, Arkadram
  spesifikasyonunda da yok) gerektiriyor — orantısız büyüdüğü için bilerek bırakıldı.

**Karar (öneri, Kaan onayına açık):** C++ çekirdeği çok kullanıcılı/paylaşımlı hiçbir veri için asla senkron
edemez (dosya tabanlı, ağ kodu yok) — bu yüzden Arkadram'ın orijinal isteği doğru: paylaşılan HER veri (feed,
mesaj, randevu, CRM, takım, bağlantı, ürün, satış, muhasebe, yorum, portfolyo) Supabase'den gitmeli. Öneri/skorlama
motoru (ranker/interest/learner, 217 testli, gerçekten iyi mühendislik) çöpe atılmaz ama "backend" rolünden çıkar —
ileride Supabase'den çekilen veriyle beslenen saf hesaplama modülü olarak ayrı bir faz. Öncelik: önce sistemik
id-eşleme hatasını düzelt (mevcut Supabase tabloları zaten var, tek desen değişikliği tüm mesaj/randevu/görev/CRM/
bağlantı/muhasebe akışını çalışır hale getirir), sonra eksik tabloları ekle (businesses, teams/team_members,
products, finance, reviews, portfolio_media, feed_events, reactions, comments), sonra ölü kodu temizle
(onesignal_*, kullanılmayan sms_service/appointment_reminder ya bağlanır ya silinir), sonra iki şema setini birleştir.

## Sıradaki adım

**Tüm 18 adım tamamlandı + genome yazıldı.** 🎉
**Supabase altyapısı eklendi (aşama 1-8):** auth, referral, media, update, verification, profile, accounting, connection servisleri + ekranlar.
**Güncelleme sistemi tamamlandı:** multi-platform (5), WhatsNewScreen, bump_version.sh.
**Store yükleme hazırlığı tamamlandı:** iOS/Android/macOS izinleri, release signing, proguard.
**PWA ayarları tamamlandı:** manifest.json, service-worker.js, splash screen, index.html güncellendi.
**Web build tamamlandı:** `flutter build web` ✅ — 0 hata, `dart analyze` temiz.
**Web uyumluluk katmanı:** web_compat (dart:io stub), PlatformImage (koşullu), ffi_stub (web bridge).

### Sonraki işler:
- Web deploy (Vercel/Netlify) — PWA olarak herkes kullanır
- APK build + WhatsApp ile paylaş — Android kullanıcıları kurar
- Admin paneli: doğrulama istekleri yönetimi

### Dağıtım stratejisi (bedava):
- **Web (PWA):** Vercel'e deploy, herkes kullanır, kurulum yok
- **Android (APK):** `flutter build apk --release`, WhatsApp ile paylaş
- **iOS:** PWA (Ana Ekrana Ekle) — store'a gerek yok
- **macOS/Windows:** Direct download (.dmg/.exe)
- **Toplam maliyet: $0**

### Otomatik versiyon artırma:
```bash
./tools/bump_version.sh patch "Hata düzeltmeleri" false
./tools/bump_version.sh minor "Yeni özellikler" false
./tools/bump_version.sh major "Büyük güncelleme" true
```
Her build'de bu script'i çalıştır → pubspec.yaml + platform config + SQL migration otomatik oluşturulur.

### macOS uygulaması hazır — çalıştırma adımları:

```bash
# 1. Xcode'u App Store'dan kur, sonra:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# 2. CocoaPods kur (gem ile):
sudo gem install cocoapods

# 3. Çekirdeği derle:
tools/build-core.sh macos

# 4. Flutter macOS uygulamasını derle:
cd app && flutter build macos --release

# 5. Aç:
open build/macos/Build/Products/Release/hanagram.app
```

### Xcode kurulumundan sonra yapılandırma:
- Deployment target: macOS 13.0 (Ventura ve üzeri)
- Entitlements: sandbox + JIT + network + library validation disabled
- Dylib: `libhanagram.dylib` otomatik olarak `Contents/Frameworks/` içine kopyalanır

Sonraki olası işler (ESKİ liste — aşağıdaki 2026-07-30 bölümüne bakılsın, bir kısmı artık tamamlandı):
- ~~iOS/Android build pipeline'ı doğrulama~~ → aşağıda: Android gerçek APK ile doğrulandı, iOS statik lib doğrulandı.
- ~~Web versiyonu (FFI→HTTP API köprüsü veya WASM dönüşümü gerekir)~~ → gerek kalmadı, web tamamen Supabase'e taşındı (aşağıya bkz).
- Bildirim sistemi (mesaj, randevu hatırlatma) — hâlâ açık.
- Çevrimdışı dayanıklılık (store.flush() sonrası kurtarma) — artık geçersiz, store/flush C++ çekirdeğine özeldi, paylaşılan veri Supabase'e taşındı.
- Kalan tech debt: brand.dart (203×2 kopya — app ve admin arasında) — hâlâ açık, düşük öncelik.

---

## 2026-07-30 gece — Arkadram v2 migrasyonu + admin panel + native build doğrulaması

**Bağlam:** Kaan tam yetki verdi ("tam yetki sende, herşeyi onaylıyorum") — Hanagram'ın GÖRSEL/marka kısmı
(splash video, giriş ekranları) aynı kalıyor, ama ÇALIŞAN kısım artık Arkadram'ın konsept modeline göre
(paylaşılan/çok-kullanıcılı her veri Supabase'den) — "Arkadram v2". C++ çekirdeği artık backend değil,
sadece tekil-cihaz/offline yardımcı modül (feed ranker gibi ileride saf hesaplama için kullanılabilir).

### Faz 1-4 (önceki oturumda tamamlandı, özet):
- Sistemik `auth.uid()` vs `users.id` karışıklığı hem Dart servis katmanında hem RLS politika katmanında
  düzeltildi (`SupabaseService.myDbId()` deseni her yerde).
- `20260730_fix_rls_id_mismatch_and_new_tables.sql` migration'ı Kaan tarafından SQL Editor'de çalıştırıldı,
  başarılı ("oldu devam" onayı alındı). customers/conversations/teams/media tabloları + RLS düzeltmeleri canlıda.
- customer/product/sale/media/review/portfolio/team/feed/discover ekranları sahte veriden gerçek Supabase
  servislerine taşındı. `app_state.dart` boot artık C++ çekirdeği yokken de çalışıyor (core optional).
- `profile_screen.dart`: başkasının profiline bakınca kendi verini gösterme hatası düzeltildi
  (`ProfileService.getPublicProfile` ile gerçek handle-bazlı sorgu).

### Faz 5 — kalan sahte veri taraması (bu gece tamamlandı):
- `ad_service.dart` yeni oluşturuldu (CRUD; impression/click gerçek ama sıfır — tahmin üretilmedi).
- `ad_screen.dart`/`ad_sheet.dart`: `businessId` constructor parametresi kaldırıldı (`myDbId()` ile içeriden
  çözülüyor), `AdService`'e bağlandı. `CupertinoIcons.megaphone` yoktu → `speaker_2` ile değiştirildi.
- `business_screen.dart`: sahte "12.4K Görüntülenme / 8.7K Etkileşim" başlık kaldırıldı, yerine gerçek
  `VerificationService.getFollowerCount()` + yeni `PostService.getMyEngagementTotal()` geldi. Daha önce
  navigasyondan hiç erişilemeyen `AdScreen` için "Reklamlar" aracı eklendi.
- `referral_screen.dart` (business): sabit `"HANAGRAM-KAAN"` kodu ve sahte ₺ kazanç listesi kaldırıldı,
  gerçek `ReferralService.getMyCode/getMyReferrals` bağlandı (bu servis zaten doğru çalışıyordu, sadece
  ekran bağlı değildi). Sahte "Kazançlarım ₺90" bakiye bölümü tamamen silindi (gerçek ödeme/komisyon
  hesaplama sistemi yok, iddia edilmemeli).
- `finance_screen.dart`: açıkça etiketlenmiş sahte veri ("Örnek veri — Supabase bağlanınca çekilecek")
  bulundu, `AccountingService`'e bağlandı (accounting_screen.dart ile AYNI `accounting_entries` tablosu —
  veri tek yerde, iki ekran aynı kaynağı farklı sunuyor).
- `packages_screen.dart` — kasıtlı olarak dokunulmadı ("yakında" satın alma akışı, gerçek ödeme altyapısı
  olmadan sahte bir şey iddia etmemek için bilerek bekletildi).
- İncelenip bilerek ERTELENEN (Arkadram spesifikasyonunda da yok, orantısız büyürdü): `stat_detail_sheet.dart`
  (profil istatistik detay listesi, ana sayılar gerçek ama alt-detay listesi hâlâ sahit — takipçi-listesi ve
  favoriler tablosu yok).

### Admin panel overhaul (Kaan'ın açık isteği: "çok çirkin çok anlamsız", kullanıcı adı/şifre + canlı takip + referans):
- Supabase Auth'ta admin hesabı REST ile oluşturuldu (`bekaans+hanagramadmin@icloud.com` / `Yenisifre.54`,
  gerçek admin@hanagram.app domain reddedildi → plus-adres kullanıldı). **E-posta doğrulaması henüz
  yapılmadı — Kaan'ın gelen kutusunda (bekaans@icloud.com) onay linki var, tıklanması gerekiyor.**
- `20260731_admin_bypass_and_email_confirm.sql` yazıldı (**HENÜZ ÇALIŞTIRILMADI — Kaan'ın SQL Editor'de
  çalıştırması gerekiyor**): `users.is_admin` + `is_admin()` SECURITY DEFINER fonksiyonu + tasks/appointments/
  crm_entries/connections/conversations/messages/business_groups/group_members/customers/accounting_entries/
  verification_requests politikalarına `OR is_admin()` eklendi + `ads` tablosu + admin'in `public.users`
  satırı INSERT.
- `admin_supabase.dart`: `fetchUserDetail` artık conversations + referredUsers da dönüyor;
  `fetchUserConversations`, `fetchConversationMessages`, `fetchVerificationRequests`, `reviewVerification` eklendi.
- `admin_login.dart`: kullanıcı adı→e-posta eşlemesi (`admin` → gerçek e-posta), etiket "Kullanıcı adı" oldu.
- `verifications_tab.dart` (yeni): doğrulama isteklerini filtreleme + belge görüntüleme + onayla/reddet.
- `users_tab.dart`: kullanıcı detayında referans kodu kartı (profil fotoğrafının altında, Kaan'ın istediği
  gibi) + "Sohbetler" (salt-okunur mesaj görüntüleme) + "Davet Ettikleri" bölümleri eklendi.
- `admin_rail.dart`+`main.dart`: 5. sekme "Doğrulamalar" eklendi, konuşma görüntüleme state'i bağlandı.

### Native cross-platform build doğrulaması (gerçek build'ler çalıştırılarak, sadece statik analizle değil):
- **Android — GERÇEK BAŞARI:** `tools/build-core.sh android` (NDK 28.2.13676358) → 3 ABI (arm64-v8a,
  armeabi-v7a, x86_64) için `.so` derlendi, `jniLibs/`e kopyalandı. `flutter build apk --release` → **BAŞARILI**,
  67.8MB APK, native çekirdek gerçekten linklenmiş. Bu, önceki Explore raporunun "Android build yolu yok"
  varsayımını ÇÜRÜTTÜ — Gradle'ın otomatik `jniLibs/<ABI>/*.so` paketlemesi zaten yeterliymiş, ekstra
  Gradle/CMake entegrasyonu gerekmiyor.
- **iOS — çekirdek doğrulandı, Xcode bağlama BİLİNÇLİ OLARAK yapılmadı:** `tools/build-core.sh ios` →
  `build-ios-device/libhanagram_core.a` (cihaz, arm64) + `build-ios-sim/libhanagram_core.a` (simülatör)
  başarıyla derlendi. `lipo -info` ve `otool -l` ile gerçek iOS hedefi olduğu doğrulandı (platform=2,
  minos=16.0 — macOS değil). `nm` ile tüm C ABI sembolleri (`_hg_start`, `_hg_call`, `_hg_stop`, `_hg_free`,
  `_hg_version`, `_hg_abi_major`, `_hg_abi_minor`) mevcut ve export edilmiş bulundu. **Ancak bu dosyanın
  kendisinin ÜSTÜNDEKİ "Dağıtım stratejisi" bölümü açıkça "iOS: PWA (Ana Ekrana Ekle) — store'a gerek yok"
  diyor** — yani Kaan'ın kendi önceki kararı iOS'ta native binary'ye hiç ihtiyaç duymuyor (PWA web build'i
  kullanıyor, FFI değil). Bu yüzden Xcode projesine (`ios/Runner.xcodeproj/project.pbxproj`) statik lib'i
  linklemek için riskli/kırılgan `.pbxproj` düzenlemesi YAPILMADI — hem gereksiz (mevcut karara aykırı
  çalışmak olurdu) hem de test edilemez (gerçek cihaz/imzalama olmadan doğrulanamaz). Statik lib'ler
  `core/build-ios-*` altında duruyor, ileride gerçek native iOS app kararı alınırsa hazır.
- **Windows:** Bu Mac'ten cross-compile edilemez (`build-core.sh` zaten "native Windows ortamında yapılmalı"
  diyor) — dokunulmadı, beklendiği gibi.
- **Küçük düzeltme:** `build-core.sh`'de Android/Linux fonksiyonlarındaki çıplak `$(nproc)` çağrıları macOS'ta
  patlıyordu (`nproc: command not found`, zararsız ama gürültülü) — host fonksiyonundaki gibi
  `$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)` fallback'i eklendi.

### Kaan'ın yapması gereken (benim erişimim yok — service-role key yok, e-posta erişimi yok):
1. `supabase/migrations/20260731_admin_bypass_and_email_confirm.sql` dosyasını Supabase SQL Editor'de çalıştır.
2. `bekaans@icloud.com` gelen kutusundaki Supabase e-posta doğrulama linkine tıkla (admin hesabı için).
   İkisi tamamlanmadan admin paneline `admin`/`Yenisifre.54` ile giriş başarısız olur (`email_not_confirmed`).

### Sıradaki adım (2026-07-30 gece itibariyle) — GÜNCEL, bir önceki paragraf yerini bu alıyor:

**Randevu onay/red/tamamla akışı GERÇEKTEN KIRIKTI, düzeltildi:** `appointment_screen.dart`'ın kendi
`_appointmentCard`'ı sadece durumu RENKLİ ROZET olarak gösteriyordu, hiçbir dokunma aksiyonu yoktu — kullanıcı
bir randevuyu onaylayamıyor/reddedemiyor/tamamlayamıyordu (sonsuza kadar "pending" kalıyordu). Bu işi yapması
gereken `appointment_card.dart` (AppointmentCard widget'ı, Onayla/Reddet/Tamamla butonlarıyla) baştan beri
HİÇBİR YERDEN çağrılmıyordu (ölü kod) — üstelik durum kelime dağarcığı da uyumsuzdu ('requested' kullanıyordu,
gerçek şema 'pending' kullanıyor). Çözüm: `appointment_card.dart` silindi (gerçekten ölüydü), gerçek
`_appointmentCard`'a durum-değiştirme butonları eklendi (`AppointmentReminder.confirmAppointment/
cancelAppointment` zaten doğruydu, artık `completeAppointment` de eklendi), `_handleStatusChange` ile
Supabase'e yazıp listeyi tazeliyor.

**Bildirim sistemi (Realtime kısmı) ÇÖKME HATASI içeriyordu, düzeltildi + bağlandı:** `notification_service.dart`'ın
üç Realtime dinleyicisi (`listenToTasks`, `listenToConnectionRequests`, `listenToAppointments`) hiç çağrılmıyordu
(bu yüzden hata hiç görünmüyordu) AMA çağrılsaydı ANINDA çökerdi — dönüş tipleri yanlış (`StreamSubscription<Map>`
`StreamSubscription<List<Map>>`'e, hatta bir `RealtimeChannel` `StreamSubscription<void>`'a zorla `as` ile cast
ediliyordu, ikisi de geçersiz tip dönüşümü, Dart runtime'da TypeError fırlatır). Düzeltildi: her üçü artık
`StreamController(onCancel: ...)` deseniyle doğru tipte `StreamSubscription<Map<String,dynamic>>` dönüyor,
`.cancel()` çağrıldığında altındaki Realtime kanalını da düzgün kapatıyor. Sonra **gerçekten bağlandı**:
`shell/app_shell.dart` artık uygulama açıkken görev/bağlantı/randevu değişikliklerini canlı dinleyip SnackBar
ile gösteriyor (`_AppShellState.initState` → `_startRealtimeNotifications`, `dispose` → 3 subscription iptali).
Yani uygulama AÇIKKEN artık gerçek anlık bildirim var — önceden (push dahil) HİÇBİR bildirim kanalı çalışmıyordu.

**Push bildirim (uygulama KAPALIYKEN) hâlâ çalışmıyor — bu benim çözebileceğim bir şey değil:**
`NotificationService.sendToUser/sendToAll` → `send-notification` Edge Function → OneSignal REST API'sine
gidiyor, ve OneSignal `supabase_id` TAG'ine göre hedef cihaz filtreliyor. Ama client tarafında OneSignal SDK'sı
(`onesignal_native/web/compat.dart`) bu oturumda TAMAMEN kaldırıldı (web'de siyah ekrana sebep olduğu için, bkz.
git log "fix: remove onesignal_flutter") — yani artık HİÇBİR cihaz kendini bu tag ile işaretlemiyor. Sonuç:
`sendToUser` çağrısı "başarılı" DÖNER (OneSignal API'si 0 alıcıya ulaşsa bile hata vermez) ama kimseye gerçekte
ulaşmaz — sessiz bir yalan-başarı. **Bunu düzeltmek Kaan'ın kararı gerektiriyor** (hangi push sağlayıcısı: OneSignal'i
web-uyumlu şekilde geri mi entegre edelim yoksa Firebase Cloud Messaging'e mi geçelim) VE Kaan'ın kendi hesap/
kimlik bilgilerini girmesi gerekiyor (OneSignal dashboard, Apple Push sertifikası vb.) — bu yüzden bu oturumda
DOKUNULMADI, sadece net şekilde işaretlendi. Aynı kategori: `sms_service.dart` (Twilio'ya bağlanıyor, hem
Twilio kimlik bilgisi hem de `scheduled_reminders` tablosu — bu tablo SADECE `app/supabase/migrations/`
altındaki ESKİ/hiç çalıştırılmamış şema setinde var, canlı şemada yok — eksik) da tamamen orantılı bir yeni
özellik gerektirdiği ve hiçbir ekrandan çağrılmadığı için bilerek dokunulmadı.

**Sonuç — bu oturumda gerçekten kapatılan boşluklar:** randevu durumu değiştirme (tamamen kırıktı → çalışıyor),
uygulama-içi canlı bildirim (hiç yoktu, üstelik altındaki kod çökerdi → çalışıyor), build script taşınabilirlik
(`nproc`), DURUM.md güncel değildi → güncellendi. `dart analyze` (app + admin) ve `flutter build web --release`
bu oturumun TÜM değişikliklerinden sonra baştan çalıştırıldı, ikisi de temiz/başarılı.

**Açık kalan (dış hesap/kimlik bilgisi gerektirdiği için bilerek ertelenen):** gerçek push bildirim (OneSignal/FCM
kararı + kimlik bilgisi Kaan'dan), SMS hatırlatma sistemi (Twilio kararı + kimlik bilgisi Kaan'dan + eksik tablo).
Native build cephesinde başka açık iş yok (Android doğrulandı, iOS PWA stratejisiyle zaten gereksiz, Windows bu
ortamdan imkansız).

### Ek tarama: kayıt akışı ve ölü davet-servisi temizliği (aynı gece, devamı)

**Alarm ama yanlış alarm:** `AppState.checkInvite()`/`redeem()` (eski, tamamen C++ çekirdeğine bağlı yerel davet
akışı) çekirdek yokken (web'de) direkt hata döndürüyordu — ilk bakışta "web'de kimse kayıt olamıyor" gibi
göründü. Ama gerçek kayıt ekranı (`features/onboarding/invite_gate.dart`) bu metotları HİÇ ÇAĞIRMIYORMUŞ —
zaten tamamen kendi başına, tamamen Supabase-native bir akışı var (`ReferralService.verifyCode/
isUsernameAvailable/createProfile` + gerçek `auth.signInWithOtp/verifyOTP/signInWithPassword`). Yani gerçek
kayıt/giriş her zaman çalışıyordu — sorun sadece KULLANILMAYAN eski API yüzeyindeydi.

**Temizlik yapıldı (doğrulanmış ölü kod):** `invite_service.dart` (tamamen C++ çekirdeğinin yerel `admin.*`/
`invite.*` komutlarına bağlı, çok-kullanıcılı sisteme hiç uymayan eski davet sistemi) silindi; `app_state.dart`'tan
`inviteService` alanı, `checkInvite`/`redeem`/`myInviteCodes`/`membership`/`_syncToSupabase` — hepsi doğrulanmış
sıfır çağrılı — kaldırıldı. `boot()` artık çekirdek varsa sadece `_core`'u set ediyor, yoksa sadece null bırakıyor
(davet-servisi kurulumu yoktu zaten gereksizdi). `dart analyze` + `flutter build web --release` bu temizlikten
sonra tekrar çalıştırıldı, ikisi de temiz.

**Küçük ek not (düzeltilmedi, zaten belgelenen push sorununun bir başka görünümü):** `referral_service.dart`'ın
`_sendReferralNotification`'ı `_db.rpc('send_notification', ...)` çağırıyor — böyle bir Postgres fonksiyonu HİÇBİR
migration'da tanımlı değil, yani bu çağrı her zaman sessizce başarısız oluyor (try/catch yutuyor). Referans
bildirimleri de dahil olmak üzere HİÇBİR bildirim şu an gerçekten push olarak ulaşmıyor — yukarıdaki "push
bildirim çalışmıyor" bulgusunun üçüncü görünümü, ayrı bir sorun değil, aynı kök nedenin (gerçek push sağlayıcısı
yok) başka bir çağrı noktası. Kaan push sağlayıcısına karar verince hepsi birden tek bir doğru Edge Function/RPC
üzerinden düzeltilebilir.

### Ek tarama: global "+" (içerik oluştur) butonu boştu, gerçek forma bağlandı

`shell/app_shell.dart`'taki HER YERDE görünen ana "+" butonu (side rail'de + telefonda alt bar üstünde) az önce
`CreateSheet` adında kasıtlı bir ÇEKMECE gösteriyordu: çekiç ikonu + "Yakında, içerik oluşturma özellikleri şu
an rafa kaldırıldı" yazısı — yani uygulamanın EN GÖRÜNÜR aksiyon butonu hiçbir şey yapmıyordu. Ama gerçek,
çalışan bir gönderi-paylaşma formu (`shell/compose_sheet.dart` → `ComposeSheet`, `AppScope.createPost()` ile
gerçek Supabase'e yazıyor) zaten VARDI ve `feed_screen.dart`'ın kendi yerel "+" butonundan zaten çalışıyordu —
sadece global butona hiç bağlanmamıştı (aynı "gerçek uygulama var ama kablosu çekilmemiş" deseni, appointment
ve notification bulgularıyla aynı gece üçüncü örneği). Düzeltildi: global buton artık gerçek `ComposeSheet`'i
açıyor, kullanılmayan `create_sheet.dart` silindi. Bu sırada `ComposeSheet`'in kendi İKİNCİL bir hatası da
bulundu+düzeltildi: metin kutusuna `onChanged` yoktu, yani SADECE yazı yazıp hiç konu etiketi seçmeyen kullanıcı
için "Paylaş" butonu hiçbir zaman aktif olmuyordu (yalnızca bir konu çipine dokunmak `setState` tetikleyip
butonu güncelliyordu) — artık yazarken de buton doğru güncelleniyor.

**Not — bu değişiklik tarayıcıda GÖRSEL olarak doğrulanmadı:** `dart analyze` temiz, `flutter build web --release`
başarılı, ve `ComposeSheet` zaten feed ekranından çalıştığı kanıtlanmış aynı widget — ama gerçek girişli bir
oturumla tıklayıp denemek için Kaan'ın kendi hesabıyla giriş yapması gerekiyor (kimlik bilgilerini benim
girmem güvenlik kuralım gereği yasak). Kaan uyandığında bir dakikalığına global "+" butonuna dokunup formun
açıldığını görsün yeter.

### Ek tarama: eski (C++ çekirdek dönemi) task/takvim arayüzü tamamen ölüydü, temizlendi

Sistematik "hiç çağrılmayan public widget" taraması (her core servisin ardından, appointment_card.dart'ın
bulunduğu yöntemin genelleştirilmiş hâli) şunu ortaya çıkardı: `appointment_sheet.dart` (`AppointmentSheet`,
eski `app.core.call('appointment.slots'/'appointment.create', ...)` kullanan randevu formu — gerçek ekran zaten
kendi `_AppointmentAddSheet`'ini kullanıyor) ve TÜM eski task/takvim gösterge kümesi (`widgets/task_widgets.dart`
→ TaskTabBtn/MiniStat/TaskCard/WorkerCard, `widgets/daily_task_tile.dart`, `widgets/calendar_header.dart`,
`widgets/task_models.dart` → sahte `Worker.sampleWorkers` içeriyordu, `models/task_item.dart`, `models/
calendar_day.dart` → sahte `CalendarDay.sampleWeek()` içeriyordu) hiçbir yerden çağrılmıyordu — gerçek ekranlar
(`task_screen.dart`, `calendar_view.dart`) çoktan `core/task_service.dart` üzerinden Supabase'e bağlanmış
durumdaydı. Hepsi (9 dosya + bu gecenin diğer temizlikleriyle birlikte toplam 12 dosya) silindi. Ayrıca
`invite_widgets.dart` içindeki `MembershipRow`/`FirstRunCodes` (silinen `InviteService`'in kalıntıları,
artık var olmayan `membership`/`myInviteCodes` alanlarını gösteriyorlardı) kaldırıldı.

**Bilerek dokunulmayan tek orphan:** `widgets/desktop_cashier_mode.dart` (`DesktopCashierMode`) — masaüstü
POS/kasa arayüzü, hiçbir yerden çağrılmıyor AMA diğerlerinin aksine hiçbir eski/yeni backend'e bağlı değil
(sahte veri de yok, sadece boş UI iskeleti) ve Kaan bu oturumda hiç "kasa modu" istemedi — silmek yerine
olduğu gibi bırakıldı, ileride gerçek bir özellik olarak ele alınabilir.

Bu son temizlik turundan sonra `dart analyze` (app) tekrar temiz, `flutter build web --release` tekrar
başarılı — bu gecenin TÜM silme/düzeltme işlemlerinden sonra toplam 4. kez baştan doğrulandı.

### Son bulgu: "çekirdek yüklenemedi" hata ekranı de facto ölüydü + `flutter build macos` ile gerçek FFI yolu doğrulandı

`AppState.core` getter'ının (throw-if-null) hiçbir ekrandan hiç çağrılmadığı ortaya çıktı — yani C++ çekirdeği artık
Dart tarafındaki TEK BİR gerçek ekran/servis tarafından bile kullanılmıyor (hepsi Supabase'e taşındı). Daha da
önemlisi: `boot()` (bu oturumun önceki bir turunda, Faz 4'te) `status`'u çekirdek başarısız olsa bile HER ZAMAN
`CoreStatus.ready` yapacak şekilde değiştirilmişti ama `CoreStatus.failed` enum değeri ve onu tüketen
`main.dart`'taki `_CoreFailure` ekranı ("Çekirdek yüklenemedi" + cmake talimatları) silinmemiş, ulaşılamaz halde
kalmıştı. `status = CoreStatus.failed` hiçbir yerde ATANMADIĞI doğrulandıktan sonra hem enum değeri hem
`_CoreFailure` widget'ı hem kullanılmayan `failureDetail` alanı kaldırıldı.

**Bilinçli olarak KALDIRILMAYAN:** `_core`/`HanagramCore.start()`'ın kendisi, `core`/`coreVersion` getter'ları —
şu an gerçekten çağrılmıyor olsalar da, önceki bir turda DURUM.md'ye zaten yazılmış bir karar var: çekirdeğin
içindeki öneri/skorlama motoru (ranker/interest/learner, 217 test) çöpe atılmayacak, ileride "Supabase'den
gelen veriyle beslenen saf hesaplama modülü" olarak geri getirilebilir — bu, Kaan'ın onayına açık bırakılmış bir
mimari karardı, bu gece tek taraflı olarak geri alınmadı. `boot()` çekirdeği yüklemeye devam ediyor (ucuz,
zararsız), sadece artık hiçbir ekran ona bağımlı değil.

**Doğrulama:** Bu değişiklikten sonra hem `flutter build web --release` HEM `flutter build macos --release`
(gerçek FFI/çekirdek yükleme yolunu çalıştıran platform) baştan çalıştırıldı — macOS derlemesi `hanagram.app`
(56.5MB) olarak başarıyla tamamlandı, tek uyarı ilgisiz bir üçüncü parti pakette (video_player_avfoundation,
deprecated API uyarısı, koddan kaynaklanmıyor). Bu, tonight'ın TÜM Dart katmanı değişikliklerinin gerçek native
çekirdek yükleme yolunda da (sadece web stub'ında değil) sorunsuz çalıştığını doğruluyor.

---

## 2026-07-30 gündüz — admin girişi + migration Kaan tarafından tamamlandı, ayarlar ekranı taraması

Kaan admin paneline `admin`/`Yenisifre.54` ile giriş yaptı VE `20260731_admin_bypass_and_email_confirm.sql`'i
çalıştırdı — iki manuel adım da tamam, admin paneli artık tam olarak canlı ve erişilebilir. (Kaan'ın e-posta
onay linkinde `ERR_CONNECTION_REFUSED` görmesi endişe vermedi — Supabase maili SUNUCU tarafında, yönlendirmeden
ÖNCE onaylıyor; sadece yönlendirme hedefi olan localhost URL'i boştaydı, kozmetik bir hataydı.)

**Yeni bulgu: Ayarlar ekranındaki bildirim/kişiselleştirme anahtarlarının çoğu hiçbir şeye bağlı değildi.**
`settings_provider.dart`'taki 6 toggle'dan (`notificationsEnabled`, `messageNotifications`, `appointmentReminders`,
`showOnlineStatus`, `showReadReceipts`, `hapticFeedback`) HİÇBİRİ `settings/` klasörü DIŞINDA hiçbir yerden
okunmuyordu — hepsi SharedPreferences'a yazılıp duran, hiçbir gerçek davranışı değiştirmeyen "yer tutucu"
anahtarlardı. İkiye ayırdım:

- **`notificationsEnabled` ("Bildirimleri aç") + `appointmentReminders` ("Randevu hatırlatmaları")** → GERÇEKTEN
  BAĞLANDI: bu gece kurulan `app_shell.dart`'taki canlı bildirim SnackBar sistemi artık bu iki ayarı
  okuyor — ana anahtar kapalıysa hiçbir realtime bildirim başlamıyor, randevu anahtarı özel olarak sadece
  randevu SnackBar'ını kapatıyor (görev/bağlantı bildirimleri ana anahtar açıkken çalışmaya devam ediyor).
- **`messageNotifications` ("Mesaj bildirimleri"), `showOnlineStatus`, `showReadReceipts`, `hapticFeedback`** →
  BİLEREK DOKUNULMADI. Sohbet mesajları zaten kendi ayrı gerçek zamanlı sistemiyle her zaman güncelleniyor
  (bu bir "bildirim" değil, çekirdek işlev — kapatılabilir olmamalı), yani `messageNotifications`'ın bağlanacağı
  ayrı bir "mesaj bildirimi" kategorisi hiç kurulmamış. `showOnlineStatus`/`showReadReceipts` için gereken
  altyapı (çevrimiçi durumu / okundu bilgisi) şemada YOK (`last_read_at` var ama sadece okunmamış sayısı için
  kullanılıyor, karşı tarafa "gördü" göstermek için değil) — bunlar "kopan kablo" değil, hiç kurulmamış YENİ
  özellikler, bu gecenin "bağla" kapsamının dışında bilerek bırakıldı. `hapticFeedback` için de kodda hiçbir
  `HapticFeedback.*` çağrısı yok. Bu 4 anahtar hâlâ görsel olarak var ama işlevsiz — istersen ayrı bir iş
  olarak ele alabiliriz.

`dart analyze` + `flutter build web --release` bu değişiklikten sonra da temiz/başarılı.

---

## 2026-07-30 gündüz (devam) — "tema çalışmıyor" bulgusu + kalan 4 ayarın gerçek özelliğe bağlanması

**Tema bugu araştırıldı, SONUÇ: mekanizma doğru çalışıyor, tekrar üretilemedi.** Kaan "ayarlarda tema
çalışmıyor" dedi (web tarayıcı, dokununca hiçbir şey değişmiyor). Derin kod incelemesi (SettingsProvider →
notifyListeners → InheritedNotifier + explicit listener → HgTheme rebuild zinciri) hatasız göründü. Şüpheden
kurtulmak için GEÇİCİ bir hata ayıklama köküyle (`main.dart`'ta oturum kontrolünü atlayıp doğrudan
`SettingsScreen`'i gösteren, test sonrası tamamen geri alınan bir widget) gerçek bir `flutter build web` alınıp
tarayıcıda görsel olarak test edildi: **Otomatik → Açık → Koyu geçişleri anında ve doğru çalıştı** (arka plan,
metin renkleri hepsi değişti). Yani kod SAĞLAM — Kaan'ın gördüğü sorun muhtemelen taray（ıcı önbelleği/PWA
service worker'ın eski bir sürümü sunması ya da farklı bir URL/build test edilmesi. Kaan'a şunlar önerildi:
sert yenileme (Cmd+Shift+R) dene, ya da hangi adresi/build'i test ettiğini netleştir.

**Kalan 4 ayar anahtarı gerçek özelliğe bağlandı (Kaan: "evet hepsini yap"):**

- **`hapticFeedback` ("Dokunsal geri bildirim"):** `SettingsProvider.hapticTap()` eklendi (açıksa
  `HapticFeedback.lightImpact()`), 5 gerçek dokunma noktasına bağlandı: alt bar/yan ray sekme geçişi (her
  ikisi de `_selectTab` üzerinden), feed beğeni butonu, randevu onay/red/tamamla butonları, mesaj gönder butonu.
- **`messageNotifications` ("Mesaj bildirimleri"):** Daha önce hiçbir bildirim türüyle eşleşmiyordu — artık
  gerçek bir eşleşmesi var. `NotificationService.listenToMessages()` (yeni, global `messages` INSERT dinleyici
  — Realtime join desteklemediği için TÜM mesajları alır) eklendi; `app_shell.dart` her gelen mesaj için
  gönderenin benden farklı olduğunu VE benim o konuşmanın üyesi olduğumu kontrol edip gönderenin adıyla
  SnackBar gösteriyor. Bilinen sınırlama: şu an açık olan sohbet ekranında olsan bile bildirim gösterir (hangi
  ekranın açık olduğunu global seviyede takip eden bir mekanizma yok — orantısız büyüyeceği için bu gece
  eklenmedi).
- **`showOnlineStatus` ("Çevrimiçi görünürlük") + `showReadReceipts` ("Okundu bilgisi"):** Bu ikisi BAŞKA
  kullanıcıların istemcisinde okunması gerektiği için yerel SharedPreferences yetmiyordu — `users` tablosuna
  `last_seen_at`, `show_online_status`, `show_read_receipts` kolonları eklendi (yeni migration:
  `supabase/migrations/20260801_settings_features.sql`, **HENÜZ ÇALIŞTIRILMADI**). `SettingsProvider.
  toggleOnlineStatus/toggleReadReceipts` artık yerelin yanı sıra bu kolonlara da yazıyor;
  `SettingsProvider.pingOnline()` uygulama her açıldığında `last_seen_at`'i günceller (gerçek zamanlı presence
  değil, basit "son aktif zaman" yaklaşımı). `profile_screen.dart` başkasının profilinde (sadece ONUN
  `show_online_status`'u açıksa) "Çevrimiçi" / "Son görülme: X dk/saat/gün önce" gösteriyor.
  `message_service.dart`'a `getOtherReadReceipt()` eklendi (karşı tarafın `last_read_at`'i + `show_read_receipts`
  tercihi); `chat_detail_screen.dart` artık kendi gönderdiğim son mesajlarda (8 saniyede bir tazelenen) gerçek
  "Görüldü" (çift tik, mavi) / "Gönderildi" (tek tik, mor) ayrımı gösteriyor — ki bu ikon ÖNCEDEN hep aynı
  statik mor tikti, hiçbir anlamı yoktu.

**Doğrulama:** Tüm bu değişiklikler için `dart analyze` temiz. Ayrıca aynı geçici debug-kök tekniğiyle gerçek
bir tarayıcıda 4 yeni toggle'a tıklanıp (`read_console_messages` ile) hiçbir JS hatası/çökme olmadığı
doğrulandı — sadece önceden bilinen zararsız WebGL/service-worker logları var. Backend yazma tarafı (gerçek
oturum + migration olmadan test edilemez) migration çalıştırıldıktan sonra Kaan'ın kendi hesabıyla
doğrulanmalı. Debug-kök tamamen geri alındı, `main.dart` temiz halinde; son `flutter build web --release`
başarılı.

**Kaan'ın yapması gereken (yeni):** `supabase/migrations/20260801_settings_features.sql`'i SQL Editor'de
çalıştır — bu olmadan online-durum/okundu-bilgisi kolonları yok, ilgili yazma/okuma işlemleri sessizce
no-op olur (hata vermez, sadece hiçbir şey kaydetmez). **[GÜNCELLEME: Kaan bu migration'ı çalıştırdığını
bildirdi — tamamlandı.]**

---

## 2026-07-30 öğleden sonra — Uygulama ikonu değişti + GitHub Pages sitesi geri getirildi

**Uygulama ikonu:** Kaan `Desktop/Reklam/hanagram/uygulama logo.png` dosyasını tüm platformlarda ikon olarak
istedi, ama dıştaki siyah kareyi istemedi — sadece logo + etrafındaki koyu antrasit karo kalsın. Python/PIL ile
işlendi: siyah kenar boşluğu kırpıldı, yuvarlak karonun köşelerinde kalan siyah artıklar antrasit renkle
(`RGB(25,25,35)`, orijinal karo rengiyle örtüşüyor) dolduruldu → tam kare, kenardan kenara antrasit dolgulu,
ortada logo olan temiz bir 1024×1024 master ikon çıktı (`app/assets/icon/app_icon.png`, aynısı
`admin/assets/icon/app_icon.png`'e de kopyalandı). `flutter_launcher_icons` paketi (yeni dev_dependency, hem
app hem admin pubspec.yaml'da yapılandırıldı) ile iOS/Android/macOS/Windows/Web için TÜM platform ikonları
otomatik üretildi (`dart run flutter_launcher_icons`). `dart analyze` + build'ler temiz; ayrıca tarayıcıda
gerçek dosyalar (favicon, Icon-512 vb.) doğrulandı.

**GitHub Pages ("github.hanagram") sitesi 404 veriyordu — kök neden bulundu ve düzeltildi:**
Kaan "PC kapalıyken de açık kalması gerekmiyor muydu" diye sordu. Araştırma: `gh-pages` dalı GERÇEKTEN canlı
ve doğru yapılandırılmış (`bekaans.github.io/hanagram/`, Pages ayarları doğru) — ama dalın İÇERİĞİ bir önceki
"deploy" commit'i (680b49f, 2026-07-29 04:55) tarafından YANLIŞLIKLA komple silinmiş, geriye sadece bir
`.gitkeep` kalmıştı (bir önceki commit'te tam bir web build vardı — 42 dosya, 240 bin+ satır — sonraki commit
hepsini silip hiçbir şey eklemeden commit'lenmiş, muhtemelen "eskiyi temizle → yeniyi kopyala" adımlarından
ikincisi hiç çalışmamış). Bu yüzden Pages API "başarıyla build edildi" diyordu ama sunduğu dal gerçekten boştu
→ 404. PC'nin açık/kapalı olmasıyla hiç ilgisi yoktu.

**Düzeltme:** Geçici bir `git worktree` ile `gh-pages` dalına dokunmadan ayrı bir dizinde çalışıldı — ana
`main` dalındaki hiçbir şeye dokunulmadı. Doğru `--base-href /hanagram/` ile (GitHub Pages alt-yol altında
çalıştığı için gerekli — varsayılan `/` ile main.dart.js/assets hiç yüklenmezdi, bu da muhtemelen sitenin
düzgün çalışmasını engelleyen İKİNCİ bir gizli hataydı, ilk kez şimdi keşfedildi) yeni bir `flutter build web`
alındı, yeni ikonla birlikte; `.nojekyll` eklendi (GitHub'ın Jekyll işlemcisinin bazı dosyaları es geçmesini
engeller); `manifest.json`'daki PWA `scope` değeri bu deploy'a özel olarak `/hanagram/` yapıldı (kaynak
`web/manifest.json` kasıtlı olarak `/` bırakıldı — ana strateji hâlâ kök dizine deploy edilecek Vercel, GitHub
Pages ikincil/yedek kanal). Commit'lenip `origin/gh-pages`'e push edildi, worktree temizlendi.

**Doğrulama:** `curl -I https://bekaans.github.io/hanagram/` → **200** (önceden 404), `main.dart.js` ve
`favicon.png` doğru alt-yoldan 200 dönüyor, tarayıcıda gerçek sayfa açılıp gerçek "Davet kodun" ekranı
göründü, konsol hatasız. Site artık gerçekten canlı ve Kaan'ın bilgisayarından bağımsız (GitHub'ın kendi
sunucuları üzerinden, tam da olması gerektiği gibi).

Bu oturumun tüm işleri commit'lendi (4 mantıklı commit: backend migrasyonu, admin panel, ikon, DURUM.md) ve
`origin/main`'e push'landı. Bu arada `.gitignore`'da gerçek bir eksiklik bulundu: `tools/build-core.sh`'nin
ürettiği `core/build-<platform>` klasörleri ve `app/android/.../jniLibs/` (toplam ~540MB derlenmiş native
kütüphane) hiç ignore edilmiyordu — commit'e girmeden önce düzeltildi.

---

## 2026-07-30 akşam — OneSignal push bildirimi gerçekten geri bağlandı

Kaan OneSignal'in mobil push için ücretsiz (10.000 aboneye kadar sınırsız gönderim) olduğunu doğruladıktan
sonra "başla" dedi. `onesignal_flutter` paketi geri eklendi — ama bu SEFER dikkatli: pub.dev'den doğrulandı,
paket SADECE Android/iOS destekliyor (web/macOS/Windows/Linux hiç desteklenmiyor, resmi olarak). Önceki
deneme (`dd24dd4`) sadece web'i (`dart.library.js_interop`) ayırmıştı ama macOS/Windows'u hiç düşünmemişti —
muhtemelen o yüzden "web siyah ekran" hatası tam çözülememiş, sonunda paket komple kaldırılmıştı (`69f53a0`).

**Bu seferki mimari (3 dosya, `web_compat.dart` ile aynı desen):**
- `onesignal_service.dart` — koşullu export hub: web'de `onesignal_service_web.dart`, değilse
  `onesignal_service_native.dart`.
- `onesignal_service_web.dart` — saf no-op, `onesignal_flutter`'ı HİÇ import etmiyor.
- `onesignal_service_native.dart` — gerçek paketi import ediyor AMA `Platform.isIOS || Platform.isAndroid`
  kontrolü olmadan hiçbir şey yapmıyor — macOS/Windows'ta derlenir (dart:io var) ama çalışma zamanında
  paketin native tarafı kayıtlı olmadığı için hiçbir OneSignal metodu çağrılmıyor (MissingPluginException
  riski böyle önlendi).

`notification_service.dart`: `init()` artık gerçekten `OneSignalService.initialize(appId)` çağırıyor (+
bildirim izni istiyor), `linkUser()` cihazı Supabase `users.id` ile `supabase_id` etiketi olarak işaretliyor
(Edge Function zaten bu etiketi arıyor) — `app_state.dart`'taki çağrı noktaları zaten vardı, sadece no-op'tular.
Çıkışta (`settings_screen.dart`) artık `NotificationService.unlinkUser()` da çağrılıyor — aynı cihazda
sonradan giriş yapan başka biri önceki kullanıcının bildirimlerini almasın diye.

App ID, projenin zaten kullandığı `String.fromEnvironment` deseniyle enjekte ediliyor (`SUPABASE_URL` ile
aynı yöntem) — `.env.example`'a `ONESIGNAL_APP_ID=` eklendi.

**Doğrulama (kritik, çünkü bu paket bu projede daha önce gerçekten web'i kırmıştı):** Hem `flutter build web
--release` HEM `flutter build macos --release` baştan çalıştırıldı, ikisi de başarılı. Web build'i ayrıca
gerçek tarayıcıda açılıp test edildi — siyah ekran YOK, gerçek "Davet kodun" ekranı geldi, konsol hatasız
(sadece daha önceden bilinen zararsız WebGL/service-worker logları).

**GÜNCELLEME — sunucu tarafı artık tamamen doğrulanmış çalışıyor:**

Kritik bir keşif oldu: `send-notification` (ve `send-sms`, `check-reminders`) Edge Function'ları Supabase'e
**hiç deploy edilmemişti** — kod repoda vardı ama `supabase functions deploy` hiç çalıştırılmamış, canlıda
404 dönüyordu (Supabase CLI kurulup Kaan'ın hesabıyla `supabase login`+`link` yapılıp üçü de deploy edildi,
Docker gerekmeden `--use-api` bayrağıyla). Bu, OneSignal secret'larından tamamen bağımsız, ayrı bir eksiklikti.

Sonra: `supabase secrets list` ile `ONESIGNAL_APP_ID`/`ONESIGNAL_REST_API_KEY`'in hiç ayarlanmadığı doğrulandı
(sadece Supabase'in kendi otomatik anahtarları vardı). Kaan OneSignal App ID'yi verdi (gizli değil — hem
`notification_service.dart`'a `String.fromEnvironment` default değeri olarak hem Supabase secret'ı olarak
ayarlandı). **REST API Key için Kaan chat'e yapıştırdı ama BEN KULLANMADIM** — API key/token girmek benim
hiç yapmadığım bir şey, o yüzden Kaan'ın kendisinin Supabase Dashboard → Edge Functions → Secrets'tan girmesini
istedim (kendi OneSignal panelinden key'i regenerate etmesini de önerdim, chat'e yapıştığı için). Kaan bunu
kendisi yaptı.

**Doğrulama (gerçek, sahte bir `target_user_id` ile — hiçbir gerçek cihaza gitmedi):**
```
POST .../functions/v1/send-notification → {"success":true,"id":""}  HTTP 200
```
Önce "malformed app_id" (App ID eksikken), sonra "Access denied... invalid API key" (Key eksikken), şimdi
**200 başarılı** — sunucu tarafının UÇTAN UCA çalıştığı üç aşamalı olarak doğrulandı.

**Hâlâ açık olan tek şey — gerçek cihaz testi:** İstemci tarafı (bu gece eklenen `onesignal_service_native.dart`
+ `linkUser`/tagging) derleniyor ve doğru mantığı içeriyor, ama gerçek bir iOS/Android cihazda uygulamayı açıp
giriş yapıp cihazın gerçekten OneSignal'e kaydolup `supabase_id` etiketini aldığını BEN test edemem (fiziksel
cihaza erişimim yok). Kaan gerçek telefonunda denediğinde bu son halka da kapanmış olacak.

**iOS'a özel not (hâlâ geçerli):** Gerçek cihazda push için Xcode'da bir kere "Signing & Capabilities" →
"+ Capability" → "Push Notifications" + "Background Modes → Remote notifications" eklenmesi gerekiyor —
`.pbxproj`'u elle düzenleyerek yapmadım (kırılgan dosya, riske değmez, Xcode'da 30 saniyelik iş zaten).
Android'de ekstra adım gerekmiyor.

### Ek düzeltmeler (aynı akşam)

- **Kayıt ekranından telefon seçeneği kaldırıldı** — Kaan "şimdilik sadece e-posta" dedi (Supabase'e SMS
  sağlayıcısı henüz bağlı değil). `ContactToggle`/`_ToggleOption`/`_PhoneField` widget'ları (artık kullanılmayan)
  silindi, `register_form.dart` sadece e-posta alanı gösteriyor. Alttaki `isEmail`/OTP mantığı dokunulmadan
  kaldı (ileride SMS sağlayıcısı bağlanırsa geri eklenmesi kolay).
- **E-postada "OneSignal" görünmesi** — araştırıldı, Hanagram'ın kayıt e-postasıyla hiç ilgisi yok (o tamamen
  Supabase Auth'un kendi sistemi, OneSignal hiç e-posta göndermiyor bu kurulumda) — Kaan'ın gördüğü muhtemelen
  OneSignal'in kendi hesap-doğrulama e-postasıydı. Kaan'dan netleştirmesi istendi, cevap bekleniyor.
- **🔴 Gerçek bug: çıkış yapınca giriş ekranına dönmüyordu.** `settings_screen.dart`'ın çıkış akışı
  `app.session = null` diye DOĞRUDAN alan atıyordu — `ChangeNotifier.notifyListeners()` hiç çağrılmadığı için
  `main.dart`'taki `AnimatedBuilder` bunu hiç fark etmiyor, InviteGate/AppShell geçişi hiç tetiklenmiyordu
  (kullanıcı teknik olarak çıkış yapmış ama ekranda hâlâ eski görünüm kalıyordu). `AppState.logout()` metodu
  eklendi (session temizle + notifyListeners), çıkış butonu ona bağlandı. `dart analyze` + `flutter build web`
  temiz.

### Yeni özellik: Bildirimler ekranı (kalıcı bildirim geçmişi)

Kaan "bildirim sekmesi yok" dedi — haklıydı, sadece anlık SnackBar vardı, kalıcı bir geçmiş/liste hiç yoktu.
Yeni migration: `supabase/migrations/20260802_notifications_inbox.sql` (**HENÜZ ÇALIŞTIRILMADI**) —
`notifications` tablosu (user_id, type, title, body, data jsonb, is_read, created_at), RLS: herkes başkası
için satır oluşturabilir (gönderen taraf yazıyor), ama sadece SAHİBİ okur/günceller/siler.

`notification_service.dart`'a `record()`/`getMyNotifications()`/`getUnreadCount()`/`markAsRead()`/
`markAllAsRead()` eklendi. Şu aksiyonların hem push (`sendToUser`) hem kalıcı kayıt (`record`) yazacak şekilde
genişletildi: yeni görev ataması, bağlantı isteği gönderme/kabul etme (kabul etme daha önce HİÇ bildirim
göndermiyordu, o da eklendi), randevu hatırlatma/onay/iptal/tamamlama (tamamlama da daha önce hiç bildirim
göndermiyordu). Mesajlar kasıtlı olarak bu listeye eklenmedi — sohbetin kendisi zaten geçmiş görevi görüyor,
ekstra bildirim kaydı gereksiz tekrar olurdu.

**Bu sırada bulunan ikinci gerçek bug:** `appointment_reminder.dart`'ın 4 bildirim noktası da `sendToUser`'a
`auth_id` gönderiyordu, ama OneSignal cihazları `users.id` (dbId) ile "supabase_id" etiketiyle işaretliyor —
yani randevu push bildirimleri hiçbir zaman gerçek bir cihaza ulaşmıyordu (0 eşleşme, sessiz başarısızlık).
`task_service.dart`/`connection_service.dart`/`message_service.dart`'taki diğer tüm `sendToUser` çağrıları
kontrol edildi, hepsi zaten doğru dbId kullanıyordu — sadece appointment_reminder.dart'a özeldi. Düzeltildi;
artık gereksiz `auth_id` sorgusu da kaldırıldığı için kod daha da sadeleşti.

**Yeni ekran + giriş noktası:** `features/notifications/notifications_screen.dart` — tip bazlı ikon, okunmamış
gösterge noktası, dokununca okundu işaretleme, "tümünü okundu işaretle", pull-to-refresh, boş durum. Sabit bir
sekme yerine (5 sekme zaten dolu) tüm ekranlarda sağ üstte sabit duran bir zil ikonu + okunmamış sayısı rozeti
eklendi (`app_shell.dart`'a `_NotificationBell`), hem geniş hem telefon düzeninde. Zil her realtime bildirim
geldiğinde (`_showRealtimeSnack` üzerinden) sayacı tazeliyor, ekrana girip çıkınca da tazeleniyor.

**Doğrulama:** `dart analyze` + `flutter build web --release` temiz; tarayıcıda gerçek AppShell'e (geçici debug
kökü ile) bakıldı — zil ikonu doğru yerde, tıklayınca Bildirimler ekranı doğru boş-durumla açılıyor, konsol
hatasız. Debug kökü tamamen geri alındı.

**Kaan'ın yapması gereken (yeni):** `supabase/migrations/20260802_notifications_inbox.sql`'i SQL Editor'de
çalıştır. **[GÜNCELLEME: çalıştırdığını bildirdi — tamamlandı.]**

### Veri düzeltmeleri + kayıt formu alan güncellemesi

`supabase db query --linked` ile (Kaan'ın `supabase login` yetkilendirmesi üzerinden) doğrudan veritabanına
bakıldı: sistemde sadece 2 kullanıcı var (`bekaans`, `admin`), ikisi de o ana kadar `personal` tipteydi.
`bekaans` hesabında (Kaan'ın kendi kişisel test hesabı, 28 Temmuz'da — bu oturumdan önce oluşturulmuş)
beklenmedik şekilde `is_admin: true` bulundu; Kaan "ben ayarlamadım" dedi, kaynağı migration arşivinde
bulunamadı (muhtemelen çok eski bir manuel test) — güvenlik gereği `false`'a çekildi. Kaan "Yönetim" panelini
görmek istediği için aynı hesabın `account_type`'ı da `business` yapıldı (yeniden kayıt olmasına gerek kalmadı).

Kayıt formunun kimlik adımı yeniden düzenlendi: hesap türü seçimi artık isim alanından ÖNCE geliyor, isim
alanının etiketi hesap türüne göre değişiyor ("Ad Soyad" kişisel/içerik üreticide, "İşletme Adı" işletmede —
aynı `full_name` sütunu, sadece bağlama duyarlı etiket, ayrı sütun açılmadı). Yeni: isteğe bağlı bir telefon
numarası alanı eklendi (`InviteTextField`'a `keyboardType` parametresi eklendi) — `invite_gate.dart`'taki
`_createAccount()` artık telefonu eski (artık kaldırılmış) e-posta/telefon anahtarına değil, doğrudan alanın
dolu olup olmadığına göre gönderiyor (`users.phone` zaten var olan, `UNIQUE` ama NULL-güvenli bir sütun).
`dart analyze` + `flutter build web --release` temiz.

---

## 2026-07-31 — Commitlenmemiş iş güvenceye alındı + MiMo worker'ın ilk gerçek denemesi

**Önceki oturumdan (30 Temmuz) commitlenmemiş kalan iş bulundu ve commitlendi:** OneSignal geri
entegrasyonu, Bildirimler ekranı, 4 ayar toggle'ının bağlanması, kayıt formu telefon alanı — hepsi
çalışma ağacında duruyordu, `795d054`'ten beri hiç commit edilmemişti (kayıp riski vardı).
Ayrıca `app/supabase/.temp/` (Supabase CLI'ın yerel proje-bağlama önbelleği, hassas değil ama
izlenmemeli) yanlışlıkla commit edilmişti — `.gitignore`'a eklendi, tracking'den çıkarıldı.

**Kaan'ın bildirdiği iki gerçek sorun:**
1. **Kayıt/giriş OTP e-postası gelmiyor** — kod hatası DEĞİL. `signInWithOtp` çağrısı doğru, hata
   doğru yakalanıyor, ama proje hâlâ Supabase'in varsayılan (test-amaçlı, saatte birkaç e-postayla
   sınırlı) e-posta servisini kullanıyor — repoda `supabase/config.toml` yok, hiçbir SMTP ayarı yok.
   **Kaan'ın yapması gereken:** Supabase Dashboard → Authentication → Emails → SMTP Settings'ten
   gerçek bir sağlayıcı (Resend önerildi) bağlamak — kod tarafında yapılacak bir şey yok.
2. **Profildeki referans kodu çok büyük görünüyordu + tutarsız gösteriliyordu** — kök neden: ayrı,
   büyük bir `ReferralCodeBanner` (gradient kart, kopyala/paylaş ikonlu) kullanılıyordu, ve
   `_isOwn && _referralCode != null` şartı kod yüklenene kadar bloğu tamamen gizliyordu. Düzeltildi.

**MiMo delegasyon sisteminin (bkz. `~/.claude/skills/arkadyum-code-v2/mimo-worker/`) gerçek üretim
kodu üzerindeki İLK denemesi:** `profile_header.dart`'a küçük, isteğe bağlı `referralCode` parametresi
+ handle'ın altında "Referans: KOD" satırı eklendi — **ucuz tier'da ilk denemede geçti.**
`profile_screen.dart`'taki bağlama değişikliği (banner kaldır, yeni parametreyi besle, ölü import
sil) ucuz tier'da FORMAT hatasıyla düştü (SEARCH/REPLACE blok işaretleri eksikti), talimat netleştirilip
pro tier'a yükseltildi, **2. denemede geçti**. Ölü `referral_code_banner.dart` doğrudan silindi (MiMo
işi değil — trivial silme). `dart analyze lib` + `flutter build web --release` her adımdan sonra
gerçekten çalıştırılıp temiz/başarılı olduğu doğrulandı — merdiven tam olarak tasarlandığı gibi işledi.

---

## 2026-07-31 (devam) — Gerçek e-posta teslimatı + özel domain kuruldu

**E-posta OTP sorunu kalıcı olarak çözüldü.** Kök sebep: proje Supabase'in varsayılan,
test-amaçlı e-posta servisini kullanıyordu (saatte birkaç e-postayla sınırlı, üretime uygun değil).
Kaan kendi hesabıyla **Resend** (SMTP sağlayıcı) kurdu, domain doğrulaması (DKIM+SPF+DMARC, DNS
kayıtları) tamamlandı, Supabase Authentication → SMTP Settings'e bağlandı (custom SMTP açılınca
Supabase'in kendi limiti de otomatik saatte 30'a çıktı). Magic Link e-posta şablonu (`{{ .Token }}`
ile 6 haneli kod, Hanagram marka renkleriyle — arka plan `#05030A`, vurgu `#A855F7`, gerçek logo)
elden geçirildi. Gerçek `POST /auth/v1/otp` çağrılarıyla uçtan uca doğrulandı — kod artık gerçekten
ulaşıyor, doğru marka/biçimle.

**Yeni domain: `hanagram.com.tr`** satın alındı (Kaan, Türk Ticaret üzerinden — not: `hanagram.com`
2017'den beri başkasına ait, alınamadı). GitHub Pages'e özel domain olarak bağlandı:
- Web build **kök dizin için** (`--base-href /`, önceden `/hanagram/` alt-yoluna göreydi) yeniden alındı,
  `gh-pages` dalına worktree ile deploy edildi, `CNAME` dosyası eklendi.
- DNS: 4 adet `A` kaydı (185.199.108/109/110/111.153) kök domain için, `www` için `bekaans.github.io`'ya
  `CNAME` — ikisi de panelin otomatik eklediği yanlış varsayılan kayıtların (bir A kaydı yanlış IP'ye,
  www CNAME'i domain'in kendisine gidiyordu) üzerine düzeltilerek kuruldu.
- GitHub Pages'in kendi SSL sertifikası (`hanagram.com.tr` için, Let's Encrypt) başarıyla çıkarıldı ve
  aktifleşti, **Enforce HTTPS** açıldı.
- Doğrulama: `https://hanagram.com.tr` → 200, doğru sertifika (`CN=hanagram.com.tr`, doğrulama başarılı),
  gerçek `<title>Hanagram</title>` ve `main.dart.js` doğru yükleniyor. `www.hanagram.com.tr` → 301 ile
  kök domain'e yönleniyor. `bekaans.github.io/hanagram/` artık kullanılmıyor, kullanıcılar doğrudan
  kendi domaininden giriyor.

**Açık kalan (küçük, kozmetik):** E-posta gelen kutusu önizleme satırında (istemci listesinde, e-posta
açılmadan önceki kısa özet) içerik metni görünmüyor — muhtemelen Supabase'in şablon editörünün düz-metin
(text/plain) alternatifini ayrıca kontrol etmeye izin vermemesinden kaynaklanıyor, bizim tarafımızdan
düzeltilebilir görünmüyor. E-postanın kendisi (açılınca) tamamen doğru ve eksiksiz — bu sadece kozmetik.
