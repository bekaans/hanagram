// Randevu testleri — SÖZLEŞME. Ajan bu dosyayı DEĞİŞTİREMEZ.
// Görev: bu testleri geçiren domain/business/appointment.cpp dosyasını yazmak.
//
// Zaman her yerde UTC ms. Sabit tarih yazmak yerine gün/saat çarpanları kullanılır:
// böylece testler makinenin saat diliminden bağımsızdır.
#include "domain/business/appointment.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::domain;

namespace {

constexpr int64_t kMin = 60000;
constexpr int64_t kHour = 60 * kMin;
constexpr int64_t kDay = 24 * kHour;

// UTC+3 — varsayılan işletme saat dilimi.
constexpr int kTz = 180;

// 1970-01-05 yerel 00:00 (UTC+3) = 1970-01-04 21:00 UTC. O gün Pazartesi'dir.
constexpr int64_t kMonday = 4 * kDay - 3 * kHour;

WorkingHours defaultHours() { return WorkingHours{}; }

Appointment appt(int64_t at, AppointmentStatus s) {
  Appointment a;
  a.id = "a1";
  a.at = at;
  a.status = s;
  return a;
}

}  // namespace

// ─────────────────────────────────────────────────────── gün ve hafta günü

TEST(dayStart_yerel_gun_basini_utc_olarak_verir) {
  // Pazartesi yerel 13:00 → aynı günün yerel 00:00'ı
  CHECK_EQ(dayStart(kMonday + 13 * kHour, kTz), kMonday);
  // Tam sınır: yerel 00:00 kendi gününe aittir
  CHECK_EQ(dayStart(kMonday, kTz), kMonday);
  // Sınırın 1 ms öncesi bir önceki güne düşer
  CHECK_EQ(dayStart(kMonday - 1, kTz), kMonday - kDay);
}

TEST(dayStart_negatif_zamanda_asagi_yuvarlar) {
  // 1969-12-31 23:59:59.999 UTC → o günün başı
  CHECK_EQ(dayStart(-1, 0), -kDay);
  CHECK_EQ(dayStart(-kDay, 0), -kDay);
  CHECK_EQ(dayStart(0, 0), 0);
}

TEST(weekdayIndex_pazartesi_sifirdir) {
  // 1 Ocak 1970 Perşembe → indeks 3
  CHECK_EQ(weekdayIndex(0, 0), 3);
  // 5 Ocak 1970 Pazartesi → 0
  CHECK_EQ(weekdayIndex(4 * kDay, 0), 0);
  // 11 Ocak 1970 Pazar → 6
  CHECK_EQ(weekdayIndex(10 * kDay, 0), 6);
  // Negatif: 31 Aralık 1969 Çarşamba → 2
  CHECK_EQ(weekdayIndex(-1, 0), 2);
}

TEST(weekdayIndex_saat_dilimini_hesaba_katar) {
  CHECK_EQ(weekdayIndex(kMonday, kTz), 0);
  CHECK_EQ(weekdayIndex(kMonday + 23 * kHour, kTz), 0);
  CHECK_EQ(weekdayIndex(kMonday - 1, kTz), 6);  // bir önceki gün Pazar
}

// ─────────────────────────────────────────────────────────── çalışma düzeni

TEST(workingHours_varsayilan_dokuz_ondokuz_on_slot) {
  const WorkingHours wh = defaultHours();
  CHECK(wh.isValid());
  const std::vector<int> s = wh.slotsOfDay();
  CHECK_EQ(s.size(), size_t{10});
  CHECK_EQ(s.front(), 9 * 60);
  CHECK_EQ(s.back(), 18 * 60);  // 18:00-19:00, çalışma saatini aşmaz
}

TEST(workingHours_slot_calisma_saatini_asamaz) {
  WorkingHours wh = defaultHours();
  wh.slotMinutes = 90;
  const std::vector<int> s = wh.slotsOfDay();
  CHECK_EQ(s.size(), size_t{6});
  CHECK_EQ(s.back(), 16 * 60 + 30);  // 16:30-18:00; 18:00-19:30 taşardı

  wh.slotMinutes = 45;
  CHECK_EQ(wh.slotsOfDay().size(), size_t{13});
  CHECK_EQ(wh.slotsOfDay().back(), 18 * 60);
}

TEST(workingHours_gecersiz_duzen_reddedilir) {
  WorkingHours wh = defaultHours();
  wh.endHour = wh.startHour;
  CHECK(!wh.isValid());

  wh = defaultHours();
  wh.slotMinutes = 0;
  CHECK(!wh.isValid());

  wh = defaultHours();
  wh.slotMinutes = 600;  // 480 üstü
  CHECK(!wh.isValid());

  wh = defaultHours();
  wh.tzOffsetMinutes = 900;  // ±840 dışı
  CHECK(!wh.isValid());

  wh = defaultHours();
  wh.closedDays = {7};  // 0-6 dışı
  CHECK(!wh.isValid());

  wh = defaultHours();
  wh.startHour = 9;
  wh.endHour = 10;
  wh.slotMinutes = 90;  // tek slot bile sığmıyor
  CHECK(!wh.isValid());
}

TEST(workingHours_gecersiz_duzende_slot_uretmez) {
  WorkingHours wh = defaultHours();
  wh.endHour = 5;
  CHECK(wh.slotsOfDay().empty());
}

TEST(workingHours_kapali_gun) {
  const WorkingHours wh = defaultHours();
  CHECK(wh.isClosedOn(6));   // Pazar
  CHECK(!wh.isClosedOn(0));
  CHECK(!wh.isClosedOn(5));
}

TEST(workingHours_json_gidis_donus) {
  WorkingHours wh;
  wh.startHour = 8;
  wh.endHour = 22;
  wh.slotMinutes = 30;
  wh.tzOffsetMinutes = -300;
  wh.closedDays = {0, 6};

  const WorkingHours back = WorkingHours::fromJson(wh.toJson());
  CHECK_EQ(back.startHour, 8);
  CHECK_EQ(back.endHour, 22);
  CHECK_EQ(back.slotMinutes, 30);
  CHECK_EQ(back.tzOffsetMinutes, -300);
  CHECK_EQ(back.closedDays.size(), size_t{2});
  CHECK_EQ(back.closedDays[0], 0);
  CHECK_EQ(back.closedDays[1], 6);
}

// ─────────────────────────────────────────────────────────────────── slotlar

TEST(slotsForDay_gunun_tum_slotlarini_utc_verir) {
  const WorkingHours wh = defaultHours();
  const std::vector<int64_t> s = slotsForDay(wh, kMonday);
  CHECK_EQ(s.size(), size_t{10});
  // yerel 09:00 = UTC 06:00
  CHECK_EQ(s.front(), kMonday + 9 * kHour);
  CHECK_EQ(s.back(), kMonday + 18 * kHour);
}

TEST(slotsForDay_gun_icindeki_herhangi_bir_an_ayni_sonucu_verir) {
  const WorkingHours wh = defaultHours();
  CHECK(slotsForDay(wh, kMonday) == slotsForDay(wh, kMonday + 15 * kHour));
}

TEST(slotsForDay_kapali_gunde_bostur) {
  const WorkingHours wh = defaultHours();
  CHECK(slotsForDay(wh, kMonday - kDay).empty());  // Pazar
}

TEST(isValidSlot_izgaraya_hizali_olmayani_reddeder) {
  const WorkingHours wh = defaultHours();
  CHECK(isValidSlot(wh, kMonday + 9 * kHour));
  CHECK(isValidSlot(wh, kMonday + 18 * kHour));
  CHECK(!isValidSlot(wh, kMonday + 9 * kHour + 30 * kMin));  // hizasız
  CHECK(!isValidSlot(wh, kMonday + 19 * kHour));             // kapanıştan sonra
  CHECK(!isValidSlot(wh, kMonday + 8 * kHour));              // açılıştan önce
  CHECK(!isValidSlot(wh, kMonday - kDay + 9 * kHour));       // Pazar
}

// ────────────────────────────────────────────────────────────── doluluk

TEST(slotTaken_iptal_edilen_randevu_slotu_serbest_birakir) {
  const WorkingHours wh = defaultHours();
  const std::vector<int64_t> s = slotsForDay(wh, kMonday);

  const std::vector<Appointment> list{
      appt(s[2], AppointmentStatus::Confirmed),
      appt(s[3], AppointmentStatus::Cancelled),
      appt(s[4], AppointmentStatus::Requested),
      appt(s[5], AppointmentStatus::Completed),
  };

  CHECK(slotTaken(list, s[2]));   // onaylı tutar
  CHECK(!slotTaken(list, s[3]));  // iptal serbest bırakır
  CHECK(slotTaken(list, s[4]));   // talep de tutar
  CHECK(!slotTaken(list, s[5]));  // tamamlanan geçmiştir
  CHECK(!slotTaken(list, s[6]));
}

TEST(freeSlots_dolu_ve_gecmis_slotlari_eler) {
  const WorkingHours wh = defaultHours();
  const std::vector<int64_t> s = slotsForDay(wh, kMonday);
  const std::vector<Appointment> list{appt(s[2], AppointmentStatus::Confirmed)};

  const std::vector<int64_t> free = freeSlots(wh, kMonday, list, 0);
  CHECK_EQ(free.size(), size_t{9});
  for (int64_t t : free) CHECK(t != s[2]);

  // now, 5. slotun tam üzerindeyse o slot hâlâ alınabilir
  const std::vector<int64_t> later = freeSlots(wh, kMonday, list, s[5]);
  CHECK_EQ(later.size(), size_t{5});
  CHECK_EQ(later.front(), s[5]);

  // Gün tamamen geçmişse hiçbir şey kalmaz
  CHECK(freeSlots(wh, kMonday, list, kMonday + kDay).empty());
}

TEST(freeSlots_kapali_gunde_bostur) {
  const WorkingHours wh = defaultHours();
  CHECK(freeSlots(wh, kMonday - kDay, {}, 0).empty());
}

// ──────────────────────────────────────────────────────────── durum geçişi

TEST(holdsSlot_yalnizca_bekleyen_ve_onayli) {
  CHECK(appt(0, AppointmentStatus::Requested).holdsSlot());
  CHECK(appt(0, AppointmentStatus::Confirmed).holdsSlot());
  CHECK(!appt(0, AppointmentStatus::Completed).holdsSlot());
  CHECK(!appt(0, AppointmentStatus::Cancelled).holdsSlot());
}

TEST(canTransition_izinli_geciler) {
  CHECK(canTransition(AppointmentStatus::Requested, AppointmentStatus::Confirmed));
  CHECK(canTransition(AppointmentStatus::Requested, AppointmentStatus::Cancelled));
  CHECK(canTransition(AppointmentStatus::Confirmed, AppointmentStatus::Completed));
  CHECK(canTransition(AppointmentStatus::Confirmed, AppointmentStatus::Cancelled));
}

TEST(canTransition_yasak_geciler) {
  // Onaysız tamamlanamaz
  CHECK(!canTransition(AppointmentStatus::Requested, AppointmentStatus::Completed));
  // Geri dönüş yok
  CHECK(!canTransition(AppointmentStatus::Confirmed, AppointmentStatus::Requested));
  // Son durumlardan çıkış yok
  CHECK(!canTransition(AppointmentStatus::Completed, AppointmentStatus::Cancelled));
  CHECK(!canTransition(AppointmentStatus::Cancelled, AppointmentStatus::Confirmed));
  // Aynı duruma geçiş işlemsizdir, geçerli sayılmaz
  CHECK(!canTransition(AppointmentStatus::Confirmed, AppointmentStatus::Confirmed));
}

// ─────────────────────────────────────────────────────────────── adlandırma

TEST(statusName_gidis_donus) {
  const AppointmentStatus all[] = {
      AppointmentStatus::Requested, AppointmentStatus::Confirmed,
      AppointmentStatus::Completed, AppointmentStatus::Cancelled};
  for (AppointmentStatus s : all) {
    AppointmentStatus back = AppointmentStatus::Completed;
    CHECK(statusFromName(statusName(s), back));
    CHECK(back == s);
  }
  CHECK_EQ(std::string(statusName(AppointmentStatus::Requested)), std::string("requested"));
  CHECK_EQ(std::string(statusName(AppointmentStatus::Cancelled)), std::string("cancelled"));

  AppointmentStatus out = AppointmentStatus::Confirmed;
  CHECK(!statusFromName("bilinmeyen", out));
  CHECK(out == AppointmentStatus::Confirmed);  // başarısızlıkta dokunulmaz
}

TEST(sourceName_gidis_donus) {
  AppointmentSource out = AppointmentSource::Business;
  CHECK(sourceFromName("customer", out));
  CHECK(out == AppointmentSource::Customer);
  CHECK_EQ(std::string(sourceName(AppointmentSource::Business)), std::string("business"));
  CHECK(!sourceFromName("", out));
}

// ─────────────────────────────────────────────────────────────── metin ve json

TEST(sanitizeNote_kirpar_ve_sinirlar) {
  CHECK_EQ(sanitizeNote("  merhaba  "), std::string("merhaba"));
  CHECK_EQ(sanitizeNote(""), std::string(""));
  CHECK_EQ(sanitizeNote("   "), std::string(""));
  CHECK_EQ(sanitizeNote(std::string(600, 'x')).size(), kMaxNoteLength);
}

TEST(sanitizeService_kendi_sinirini_uygular) {
  CHECK_EQ(sanitizeService("  Saç kesimi "), std::string("Saç kesimi"));
  CHECK_EQ(sanitizeService(std::string(200, 'x')).size(), kMaxServiceLength);
}

TEST(appointment_json_gidis_donus) {
  Appointment a;
  a.id = "apt1";
  a.businessId = "biz1";
  a.customerId = "cus1";
  a.customerName = "Ayşe Yılmaz";
  a.phone = "+905321112233";
  a.service = "Saç kesimi";
  a.note = "kısa kesim";
  a.at = kMonday + 10 * kHour;
  a.priceKurus = 45000;
  a.status = AppointmentStatus::Confirmed;
  a.source = AppointmentSource::Customer;
  a.createdBy = "u1";
  a.createdAt = kMonday;

  const Appointment b = Appointment::fromJson(a.toJson());
  CHECK_EQ(b.id, a.id);
  CHECK_EQ(b.businessId, a.businessId);
  CHECK_EQ(b.customerId, a.customerId);
  CHECK_EQ(b.customerName, a.customerName);
  CHECK_EQ(b.phone, a.phone);
  CHECK_EQ(b.service, a.service);
  CHECK_EQ(b.note, a.note);
  CHECK_EQ(b.at, a.at);
  CHECK_EQ(b.priceKurus, a.priceKurus);
  CHECK(b.status == a.status);
  CHECK(b.source == a.source);
  CHECK_EQ(b.createdBy, a.createdBy);
  CHECK_EQ(b.createdAt, a.createdAt);
}

TEST(appointment_json_durum_metin_olarak_yazilir) {
  Appointment a;
  a.status = AppointmentStatus::Cancelled;
  a.source = AppointmentSource::Customer;
  const json::Value v = a.toJson();
  CHECK_EQ(v["status"].asString(), std::string("cancelled"));
  CHECK_EQ(v["source"].asString(), std::string("customer"));
}

TEST(appointment_fromJson_eksik_alanda_varsayilana_duser) {
  const Appointment a = Appointment::fromJson(json::Value::obj());
  CHECK_EQ(a.at, int64_t{0});
  CHECK_EQ(a.priceKurus, int64_t{0});
  CHECK(a.status == AppointmentStatus::Requested);
  CHECK(a.source == AppointmentSource::Business);
}
