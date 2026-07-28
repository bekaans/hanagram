// Hanagram — müşteri (CRM) alanı (SÖZLEŞME — değiştirilemez)
//
// İşletmenin kendi müşteri defteri. Platform kullanıcısı olmak zorunda değildir:
// telefonla arayan da buraya yazılır. Hesabı varsa `linkedUserId` ile bağlanır.
//
// Tasarım kararları:
//  - Telefon TEK BİÇİMDE saklanır (E.164). Aynı kişinin "0532…" ve "+90532…"
//    diye iki kez girilmesi böyle engellenir; tekillik anahtarı telefondur.
//  - Para kuruş cinsinden tam sayıdır. Kayan nokta para tutmaz — 0.1 + 0.2 hatası
//    muhasebede kabul edilemez.
//  - Ziyaret sayacı olay anında artar, her sorguda randevu listesi taranmaz.
//  - Arama Türkçe duyarlıdır: "şükrü" araması "SUKRU" kaydını da bulur.
//  - Bu başlık randevu alanını BİLMEZ. İki modül birbirinden bağımsız derlenir;
//    aralarındaki bağı API katmanı kurar.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "../../util/json.hpp"

namespace hg::domain {

struct Customer {
  std::string id;
  std::string businessId;
  std::string name;
  std::string phone;          // normalize edilmiş (E.164) ya da boş
  std::string email;
  std::string note;
  std::vector<std::string> tags;
  std::string linkedUserId;   // platformda hesabı varsa
  int64_t createdAt = 0;
  int64_t lastVisitAt = 0;
  int64_t visitCount = 0;
  int64_t totalSpendKurus = 0;

  json::Value toJson() const;
  static Customer fromJson(const json::Value& v);
};

/// Telefonu tek biçime (E.164) indirger.
///
/// Türkiye girdileri — hepsi "+905321112233" verir:
///   "0532 111 22 33" · "(0532) 111-22-33" · "90 532 111 22 33" ·
///   "+90 532 111 22 33" · "5321112233"
///
/// Yabancı numara: girdi '+' ile başlıyorsa ülke kodu korunur, yalnızca rakamlar
/// bırakılır ("+1 (555) 123-4567" → "+15551234567").
///
/// Kural sırası: rakamlar süzülür, sonra
///   12 rakam ve "90" ile başlıyor  → "+" + rakamlar
///   11 rakam ve "0" ile başlıyor   → "+90" + son 10 rakam
///   10 rakam                        → "+90" + rakamlar
///   girdide '+' vardı ve 8-15 rakam → "+" + rakamlar
///   aksi hâlde                      → geçersiz
///
/// BOŞ GİRDİ GEÇERLİDİR ve boş sonuç verir: telefon zorunlu alan değildir.
/// Geçersizse false döner ve `out`'a dokunulmaz.
bool normalizePhone(const std::string& raw, std::string& out);

/// Arama için normalize eder: küçük harfe indirir, Türkçe harfleri ASCII
/// karşılığına çevirir, baştaki/sondaki boşluğu atar, içerideki ardışık
/// boşlukları teke indirir.
///   İ,I,ı → i    Ş,ş → s    Ğ,ğ → g    Ü,ü → u    Ö,ö → o    Ç,ç → c
/// UTF-8 güvenlidir; tanımadığı çok baytlı karakteri olduğu gibi bırakır.
std::string foldForSearch(const std::string& s);

/// Ad geçerli mi ve kırpılmış hâli. Boş ad GEÇERSİZDİR — müşterinin adı olmalı.
/// En fazla kMaxNameLength karakter (fazlası kırpılır, hata değildir).
bool sanitizeName(const std::string& raw, std::string& out);

/// Basit e-posta doğrulaması: tek '@', öncesi ve sonrası dolu, sonrasında en az
/// bir '.', nokta ne başta ne sonda, boşluk yok.
/// BOŞ GİRDİ GEÇERLİDİR — e-posta zorunlu alan değildir.
bool isValidEmail(const std::string& s);

/// Etiketi normalize eder: foldForSearch uygulanır, kalan boşluklar '-' olur,
/// sonuç en fazla kMaxTagLength bayta kırpılır (UTF-8 güvenli).
/// Boş sonuç geçersizdir.
bool normalizeTag(const std::string& raw, std::string& out);

/// Etiketi ekler. Zaten varsa hiçbir şey yapmaz ve false döner.
/// kMaxTags sınırına ulaşılmışsa da false döner.
bool addTag(Customer& c, const std::string& raw);

/// Etiketi siler. Yoksa false döner.
bool removeTag(Customer& c, const std::string& raw);

bool hasTag(const Customer& c, const std::string& raw);

/// Arama eşleşmesi. Sırasıyla:
///   1. Sorgu boşsa (ya da yalnızca boşluksa) → true; liste filtresiz gösterilir.
///   2. foldForSearch(query), foldForSearch(name) içinde geçiyorsa → true.
///   3. Sorgunun yalnızca RAKAMLARI alınır; boş değilse ve telefonun yalnızca
///      rakamları bu diziyi içeriyorsa → true. ("532 111" → "+905321112233" bulunur.)
///   4. Aksi hâlde false.
bool matchesQuery(const Customer& c, const std::string& query);

/// Tamamlanan bir randevunun müşteri sayaçlarına işlenmesi.
/// `at` ziyaret zamanı, `priceKurus` ücret. lastVisitAt yalnızca ileri gider:
/// geçmişe dönük girilen bir randevu son ziyaret tarihini geri almaz.
void recordVisit(Customer& c, int64_t at, int64_t priceKurus);

constexpr size_t kMaxNameLength = 80;
constexpr size_t kMaxTags = 12;
constexpr size_t kMaxTagLength = 24;

}  // namespace hg::domain
