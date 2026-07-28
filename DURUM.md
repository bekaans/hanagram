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

Sonraki olası işler:
- iOS/Android build pipeline'ı doğrulama (cihaz üzerinde test)
- Web versiyonu (FFI→HTTP API köprüsü veya WASM dönüşümü gerekir)
- Bildirim sistemi (mesaj, randevu hatırlatma)
- Çevrimdışı dayanıklılık (store.flush() sonrası kurtarma)
- Kalan tech debt: brand.dart (203×2 kopya — app ve admin arasında)
