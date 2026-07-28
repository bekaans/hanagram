// Hanagram — randevu alanı (SÖZLEŞME — değiştirilemez)
//
// İşletme takvimi saat dilimlerinden (slot) oluşur. Müşteri boş bir slota TALEP
// açar, işletme onaylar. İşletme kendisi eklerse onay adımı atlanır.
//
// Tasarım kararları:
//  - Zaman her yerde UTC milisaniyedir. Çekirdek `localtime` çağırmaz: yerel saat
//    kullanmak sonucu makinenin saat dilimine bağlar ve testleri oynak yapar.
//    Saat dilimi bir VERİDİR, işletmenin çalışma düzeninde taşınır.
//  - Çalışma saatleri işletmeye göre değişir; 09-19 varsayımı koda gömülmez.
//  - Talep de slotu tutar. Aksi hâlde iki müşteri aynı saati talep eder ve
//    işletme birini reddetmek zorunda kalır — kötü bir deneyim.
//  - Geçmişe randevu alınamaz. Bu kural çekirdekte, arayüzde değil.
//  - İptal edilen randevu slotu serbest bırakır ama kaydı silinmez (geçmiş).
//  - Slot ızgarası işletme genelinde tekdüzedir; çakışma kontrolü başlangıç
//    zamanı eşitliğidir. Çalışma saatleri sonradan değişirse eski randevular yeni
//    ızgaraya oturmayabilir — bilinçli kabul: geçmiş randevu taşınmaz.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "../../util/json.hpp"

namespace hg::domain {

enum class AppointmentStatus {
  Requested,   // müşteri açtı, işletme onayı bekliyor
  Confirmed,   // planlandı
  Completed,   // gerçekleşti
  Cancelled,   // iptal — slot serbest
};

enum class AppointmentSource { Business, Customer };

/// Durum adı. Bilinmeyen değer için "requested" döner.
/// Adlar JSON'a yazılan biçimdir: "requested" | "confirmed" | "completed" | "cancelled"
const char* statusName(AppointmentStatus s);
bool statusFromName(const std::string& name, AppointmentStatus& out);

/// "business" | "customer"
const char* sourceName(AppointmentSource s);
bool sourceFromName(const std::string& name, AppointmentSource& out);

struct Appointment {
  std::string id;
  std::string businessId;
  std::string customerId;   // CRM kaydı (varsa)
  std::string customerName;
  std::string phone;
  std::string service;
  std::string note;
  int64_t at = 0;           // slot başlangıcı — UTC ms
  int64_t priceKurus = 0;   // ücret, kuruş. Para asla kayan noktada tutulmaz.
  AppointmentStatus status = AppointmentStatus::Requested;
  AppointmentSource source = AppointmentSource::Business;
  std::string createdBy;    // talebi açan kullanıcı kimliği (varsa)
  int64_t createdAt = 0;

  /// Slotu meşgul sayılır mı. Requested ve Confirmed tutar; Completed geçmiştir,
  /// Cancelled serbesttir.
  bool holdsSlot() const;

  /// Alan adları buradaki üye adlarıyla birebir aynıdır; `status` ve `source`
  /// metin olarak yazılır (statusName/sourceName).
  json::Value toJson() const;
  static Appointment fromJson(const json::Value& v);
};

/// İşletmenin çalışma düzeni. Gün indeksi 0=Pazartesi … 6=Pazar.
struct WorkingHours {
  int startHour = 9;               // ilk slot bu saatte başlar
  int endHour = 19;                // son slot bu saatte BİTER, sonrasına taşmaz
  int slotMinutes = 60;
  int tzOffsetMinutes = 180;       // UTC+3 — işletmenin saat dilimi
  std::vector<int> closedDays{6};  // varsayılan: Pazar kapalı

  /// Alanlar tutarlı mı: 0 ≤ startHour < endHour ≤ 24, 5 ≤ slotMinutes ≤ 480,
  /// -840 ≤ tzOffsetMinutes ≤ 840, kapalı gün indeksleri 0-6 aralığında,
  /// ve günde en az bir slot sığıyor.
  bool isValid() const;

  bool isClosedOn(int weekday) const;

  /// Bir gündeki slot başlangıçları — gün başından itibaren DAKİKA cinsinden.
  /// Örnek (9-19, 60dk): {540, 600, …, 1080} → 10 slot, sonuncusu 18:00-19:00.
  /// Geçersiz düzende boş döner.
  std::vector<int> slotsOfDay() const;

  json::Value toJson() const;
  static WorkingHours fromJson(const json::Value& v);
};

/// Verilen anın ait olduğu yerel günün 00:00'ı — UTC ms olarak.
/// Yalnızca tam sayı aritmetiği; negatif zaman damgalarında da aşağı yuvarlar.
int64_t dayStart(int64_t ms, int tzOffsetMinutes);

/// Pazartesi = 0 … Pazar = 6. (1 Ocak 1970 Perşembe'dir → indeks 3.)
int weekdayIndex(int64_t ms, int tzOffsetMinutes);

/// Geçerli bir slot başlangıcı mı: çalışma günü, ızgaraya hizalı, düzen geçerli.
bool isValidSlot(const WorkingHours& wh, int64_t at);

/// `dayMs`'in düştüğü günün tüm slot başlangıçları (UTC ms), artan sırada.
/// Kapalı günde ya da geçersiz düzende boş döner.
std::vector<int64_t> slotsForDay(const WorkingHours& wh, int64_t dayMs);

/// Slot bir randevu tarafından tutuluyor mu (holdsSlot() && at eşit).
bool slotTaken(const std::vector<Appointment>& existing, int64_t at);

/// Dolu ve geçmiş slotları çıkarıp kalanları döndürür.
/// `at < now` olan slotlar listelenmez — geçmişe randevu alınamaz.
std::vector<int64_t> freeSlots(const WorkingHours& wh, int64_t dayMs,
                               const std::vector<Appointment>& existing,
                               int64_t now);

/// Durum geçişi geçerli mi.
///   Requested → Confirmed | Cancelled
///   Confirmed → Completed | Cancelled
///   Completed, Cancelled → (son durum, çıkış yok)
/// Aynı duruma geçiş geçersizdir (işlemsiz güncelleme hata sayılır).
bool canTransition(AppointmentStatus from, AppointmentStatus to);

/// Notu kırpar: baştaki/sondaki boşluk atılır, en fazla kMaxNoteLength BAYT
/// kalır. Boş not geçerlidir — not zorunlu alan değildir, bu yüzden başarısızlık
/// hâli yoktur ve fonksiyon doğrudan sonucu döndürür.
/// Kesme UTF-8 güvenlidir: sınır çok baytlı bir karakterin ortasına düşerse
/// bir önceki karakter sınırına çekilir (yarım karakter üretilmez).
std::string sanitizeNote(const std::string& raw);

/// Hizmet adı için aynısı, sınır kMaxServiceLength.
std::string sanitizeService(const std::string& raw);

constexpr size_t kMaxNoteLength = 500;
constexpr size_t kMaxServiceLength = 80;

}  // namespace hg::domain
