// İşletme API testleri — SÖZLEŞME. Ajan bu dosyayı DEĞİŞTİREMEZ.
// Görev: bu testleri geçiren core/src/api/business.cpp dosyasını yazmak.
//
// Bu dosya API yüzeyinin tanımıdır: metot adları, yük alanları, hata kodları ve
// yan etkiler burada yazar. Başka bir yerde ayrıca tarif edilmemiştir.
//
// Not: davet kodları O, I, L harflerini İÇERMEZ (bkz. kernel/id.cpp).
#include "domain/business/appointment.hpp"
#include "domain/business/customer.hpp"
#include "kernel/runtime.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::kernel;

namespace {

// Saat dilimi UTC+3; 1970-01-05 yerel Pazartesi'ye tam hafta katları eklenerek
// modern bir Pazartesi elde edilir (hafta günü değişmez).
constexpr int kTz = 180;
constexpr int64_t kMondayLocal = 4 * kDay - 3 * kHour + 19600LL * kDay;

json::Value obj() { return json::Value::obj(); }

// Sınır güvenli dizi erişimi. Boş diziye indekslemek çökmeye yol açar ve
// çökme, sonraki bütün test çıktısını yutar — ajan hatalarını göremez olur.
const json::Value& at(const json::Array& a, size_t i) {
  static const json::Value kNull;
  return i < a.size() ? a[i] : kNull;
}

const json::Value& at(const json::Value& arr, size_t i) { return at(arr.asArray(), i); }

json::Value call(Runtime& rt, const std::string& method, const json::Value& payload) {
  std::string err;
  return json::parse(rt.call(method, payload.dump()), &err);
}

void seedInvite(Runtime& rt, const std::string& code) {
  json::Value inv = obj();
  inv.set("code", code);
  inv.set("ownerId", "");
  inv.set("maxUses", 1);
  inv.set("usedCount", 0);
  inv.set("createdAt", rt.clock().now());
  inv.set("expiresAt", 0);
  inv.set("revoked", false);
  inv.set("redeemedBy", json::Value::arr());
  rt.store().put(coll::kInvites, code, inv);
}

std::string join(Runtime& rt, const std::string& code, const std::string& name,
                 const std::string& type) {
  seedInvite(rt, code);
  json::Value p = obj();
  p.set("code", code);
  p.set("name", name);
  p.set("accountType", type);
  return call(rt, "invite.redeem", p)["data"]["user"]["id"].asString();
}

// Kurulmuş bir dünya: işletme hesabı, çalışma saatleri ve Pazartesi 00:00'a
// ayarlanmış saat. O günün tüm slotları gelecektedir.
struct World {
  std::unique_ptr<Runtime> rt;
  FakeClock* clock = nullptr;
  std::string bizId;
  std::string personId;

  json::Value call(const std::string& m, const json::Value& p) {
    return ::call(*rt, m, p);
  }
};

World makeWorld() {
  World w;
  auto clock = std::make_unique<FakeClock>(kMondayLocal);
  w.clock = clock.get();
  w.rt = std::make_unique<Runtime>("", std::move(clock));
  w.bizId = join(*w.rt, "BERBER24", "Kuafor Ayse", "business");
  w.personId = join(*w.rt, "MUSTER38", "Ahmet Kaya", "personal");

  json::Value h = obj();
  h.set("businessId", w.bizId);
  h.set("startHour", 9);
  h.set("endHour", 19);
  h.set("slotMinutes", 60);
  h.set("tzOffsetMinutes", kTz);
  json::Value closed = json::Value::arr();
  closed.push(6);
  h.set("closedDays", closed);
  w.call("business.setHours", h);
  return w;
}

int64_t slotAt(int hourLocal) { return kMondayLocal + hourLocal * kHour; }

json::Value bookPayload(const std::string& bizId, int64_t at,
                        const std::string& name = "Ahmet Kaya") {
  json::Value p = obj();
  p.set("businessId", bizId);
  p.set("at", at);
  p.set("customerName", name);
  return p;
}

std::string statusOf(const json::Value& r) { return r["data"]["status"].asString(); }

}  // namespace

// ────────────────────────────────────────────────────────── çalışma saatleri

TEST(biz_setHours_kaydeder_ve_geri_verir) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  const json::Value r = w.call("business.hours", p);
  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["startHour"].asInt(), int64_t{9});
  CHECK_EQ(r["data"]["endHour"].asInt(), int64_t{19});
  CHECK_EQ(r["data"]["slotMinutes"].asInt(), int64_t{60});
  CHECK_EQ(r["data"]["tzOffsetMinutes"].asInt(), int64_t{kTz});
}

TEST(biz_hours_hic_ayarlanmadiysa_varsayilan_doner) {
  World w = makeWorld();
  const std::string other = join(*w.rt, "DUKKAN52", "Berber Veli", "business");
  json::Value p = obj();
  p.set("businessId", other);
  const json::Value r = w.call("business.hours", p);
  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["startHour"].asInt(), int64_t{9});
}

TEST(biz_setHours_gecersiz_duzeni_reddeder) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("startHour", 19);
  p.set("endHour", 9);
  p.set("slotMinutes", 60);
  p.set("tzOffsetMinutes", kTz);
  const json::Value r = w.call("business.setHours", p);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_INVALID_HOURS"));
}

TEST(biz_setHours_isletme_olmayani_reddeder) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.personId);
  p.set("startHour", 9);
  p.set("endHour", 19);
  p.set("slotMinutes", 60);
  p.set("tzOffsetMinutes", kTz);
  const json::Value r = w.call("business.setHours", p);
  CHECK_EQ(r["code"].asString(), std::string("ERR_NOT_BUSINESS"));
}

TEST(biz_setHours_olmayan_kullanici) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", "yok");
  p.set("startHour", 9);
  p.set("endHour", 19);
  p.set("slotMinutes", 60);
  p.set("tzOffsetMinutes", kTz);
  CHECK_EQ(w.call("business.setHours", p)["code"].asString(),
           std::string("ERR_USER_NOT_FOUND"));
}

// ─────────────────────────────────────────────────────────────── boş slotlar

TEST(apt_slots_gunun_bos_slotlarini_verir) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("dayMs", kMondayLocal);
  const json::Value r = w.call("appointment.slots", p);
  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["slots"].asArray().size(), size_t{10});
  CHECK_EQ(at(r["data"]["slots"], 0).asInt(), slotAt(9));
}

TEST(apt_slots_dolu_olani_cikarir) {
  World w = makeWorld();
  w.call("appointment.create", bookPayload(w.bizId, slotAt(10)));

  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("dayMs", kMondayLocal);
  const json::Value res1 = w.call("appointment.slots", p);
  const auto& slots = res1["data"]["slots"].asArray();
  CHECK_EQ(slots.size(), size_t{9});
  for (const auto& s : slots) CHECK(s.asInt() != slotAt(10));
}

TEST(apt_slots_gecmis_saatleri_gostermez) {
  World w = makeWorld();
  w.clock->set(slotAt(14));
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("dayMs", kMondayLocal);
  const json::Value res2 = w.call("appointment.slots", p);
  const auto& slots = res2["data"]["slots"].asArray();
  CHECK_EQ(slots.size(), size_t{5});  // 14,15,16,17,18
  CHECK_EQ(at(slots, 0).asInt(), slotAt(14));
}

TEST(apt_slots_kapali_gunde_bostur) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("dayMs", kMondayLocal - kDay);  // Pazar
  const json::Value r = w.call("appointment.slots", p);
  CHECK(r["ok"].asBool());          // metot var ve cevap veriyor
  CHECK(r["data"].isObject());
  CHECK(r["data"]["slots"].isArray());
  CHECK(r["data"]["slots"].asArray().empty());
}

// ─────────────────────────────────────────────────────────── randevu açma

TEST(apt_create_isletme_actiginda_dogrudan_onaylidir) {
  World w = makeWorld();
  const json::Value r = w.call("appointment.create", bookPayload(w.bizId, slotAt(11)));
  CHECK(r["ok"].asBool());
  CHECK_EQ(statusOf(r), std::string("confirmed"));
  CHECK_EQ(r["data"]["source"].asString(), std::string("business"));
  CHECK_EQ(r["data"]["at"].asInt(), slotAt(11));
  CHECK(!r["data"]["id"].asString().empty());
}

TEST(apt_create_musteri_actiginda_onay_bekler) {
  World w = makeWorld();
  json::Value p = bookPayload(w.bizId, slotAt(11));
  p.set("source", "customer");
  p.set("createdBy", w.personId);
  const json::Value r = w.call("appointment.create", p);
  CHECK_EQ(statusOf(r), std::string("requested"));
  CHECK_EQ(r["data"]["createdBy"].asString(), w.personId);
}

TEST(apt_create_telefonu_normalize_eder) {
  World w = makeWorld();
  json::Value p = bookPayload(w.bizId, slotAt(11));
  p.set("phone", "0532 111 22 33");
  CHECK_EQ(w.call("appointment.create", p)["data"]["phone"].asString(),
           std::string("+905321112233"));
}

TEST(apt_create_hatali_girdileri_reddeder) {
  World w = makeWorld();

  json::Value noName = bookPayload(w.bizId, slotAt(11), "");
  CHECK_EQ(w.call("appointment.create", noName)["code"].asString(),
           std::string("ERR_NAME_REQUIRED"));

  json::Value badPhone = bookPayload(w.bizId, slotAt(11));
  badPhone.set("phone", "123");
  CHECK_EQ(w.call("appointment.create", badPhone)["code"].asString(),
           std::string("ERR_INVALID_PHONE"));

  json::Value offGrid = bookPayload(w.bizId, slotAt(11) + 30 * kMinute);
  CHECK_EQ(w.call("appointment.create", offGrid)["code"].asString(),
           std::string("ERR_SLOT_INVALID"));

  json::Value closed = bookPayload(w.bizId, kMondayLocal - kDay + 9 * kHour);
  CHECK_EQ(w.call("appointment.create", closed)["code"].asString(),
           std::string("ERR_SLOT_INVALID"));
}

TEST(apt_create_gecmise_randevu_yasak) {
  World w = makeWorld();
  w.clock->set(slotAt(15));
  CHECK_EQ(w.call("appointment.create", bookPayload(w.bizId, slotAt(10)))["code"].asString(),
           std::string("ERR_PAST"));
  // Şu anki slot hâlâ alınabilir
  CHECK(w.call("appointment.create", bookPayload(w.bizId, slotAt(15)))["ok"].asBool());
}

TEST(apt_create_dolu_slotu_reddeder) {
  World w = makeWorld();
  CHECK(w.call("appointment.create", bookPayload(w.bizId, slotAt(12)))["ok"].asBool());
  CHECK_EQ(w.call("appointment.create", bookPayload(w.bizId, slotAt(12)))["code"].asString(),
           std::string("ERR_SLOT_TAKEN"));
}

TEST(apt_create_iptal_edilen_slot_yeniden_alinabilir) {
  World w = makeWorld();
  const std::string id =
      w.call("appointment.create", bookPayload(w.bizId, slotAt(12)))["data"]["id"].asString();

  json::Value cancel = obj();
  cancel.set("businessId", w.bizId);
  cancel.set("appointmentId", id);
  cancel.set("status", "cancelled");
  CHECK(w.call("appointment.setStatus", cancel)["ok"].asBool());

  CHECK(w.call("appointment.create", bookPayload(w.bizId, slotAt(12)))["ok"].asBool());
}

TEST(apt_create_baska_isletmenin_slotu_ayri) {
  World w = makeWorld();
  const std::string other = join(*w.rt, "DUKKAN52", "Berber Veli", "business");
  CHECK(w.call("appointment.create", bookPayload(w.bizId, slotAt(12)))["ok"].asBool());
  CHECK(w.call("appointment.create", bookPayload(other, slotAt(12)))["ok"].asBool());
}

// ───────────────────────────────────────────────────────────── randevu listesi

TEST(apt_list_zamana_gore_sirali) {
  World w = makeWorld();
  w.call("appointment.create", bookPayload(w.bizId, slotAt(15)));
  w.call("appointment.create", bookPayload(w.bizId, slotAt(9)));
  w.call("appointment.create", bookPayload(w.bizId, slotAt(12)));

  json::Value p = obj();
  p.set("businessId", w.bizId);
  const json::Value res3 = w.call("appointment.list", p);
  const auto& items = res3["data"]["items"].asArray();
  CHECK_EQ(items.size(), size_t{3});
  CHECK_EQ(at(items, 0)["at"].asInt(), slotAt(9));
  CHECK_EQ(at(items, 1)["at"].asInt(), slotAt(12));
  CHECK_EQ(at(items, 2)["at"].asInt(), slotAt(15));
}

TEST(apt_list_zaman_araligi_suzer) {
  World w = makeWorld();
  w.call("appointment.create", bookPayload(w.bizId, slotAt(9)));
  w.call("appointment.create", bookPayload(w.bizId, slotAt(12)));
  w.call("appointment.create", bookPayload(w.bizId, slotAt(15)));

  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("fromMs", slotAt(10));
  p.set("toMs", slotAt(15));  // üst sınır dışarıda kalır
  const json::Value res4 = w.call("appointment.list", p);
  const auto& items = res4["data"]["items"].asArray();
  CHECK_EQ(items.size(), size_t{1});
  CHECK_EQ(at(items, 0)["at"].asInt(), slotAt(12));
}

TEST(apt_list_yalnizca_kendi_isletmesini_verir) {
  World w = makeWorld();
  const std::string other = join(*w.rt, "DUKKAN52", "Berber Veli", "business");
  w.call("appointment.create", bookPayload(w.bizId, slotAt(9)));
  w.call("appointment.create", bookPayload(other, slotAt(10)));

  json::Value p = obj();
  p.set("businessId", w.bizId);
  CHECK_EQ(w.call("appointment.list", p)["data"]["items"].asArray().size(), size_t{1});
}

// ───────────────────────────────────────────────────────────── durum geçişi

TEST(apt_setStatus_gecerli_gecis) {
  World w = makeWorld();
  json::Value p = bookPayload(w.bizId, slotAt(11));
  p.set("source", "customer");
  const std::string id = w.call("appointment.create", p)["data"]["id"].asString();

  json::Value up = obj();
  up.set("businessId", w.bizId);
  up.set("appointmentId", id);
  up.set("status", "confirmed");
  CHECK_EQ(statusOf(w.call("appointment.setStatus", up)), std::string("confirmed"));
}

TEST(apt_setStatus_yasak_gecisi_reddeder) {
  World w = makeWorld();
  json::Value p = bookPayload(w.bizId, slotAt(11));
  p.set("source", "customer");
  const std::string id = w.call("appointment.create", p)["data"]["id"].asString();

  json::Value up = obj();
  up.set("businessId", w.bizId);
  up.set("appointmentId", id);
  up.set("status", "completed");  // onaysız tamamlanamaz
  CHECK_EQ(w.call("appointment.setStatus", up)["code"].asString(),
           std::string("ERR_BAD_TRANSITION"));
}

TEST(apt_setStatus_bilinmeyen_durum_ve_kayit) {
  World w = makeWorld();
  const std::string id =
      w.call("appointment.create", bookPayload(w.bizId, slotAt(11)))["data"]["id"].asString();

  json::Value bad = obj();
  bad.set("businessId", w.bizId);
  bad.set("appointmentId", id);
  bad.set("status", "uydurma");
  CHECK_EQ(w.call("appointment.setStatus", bad)["code"].asString(),
           std::string("ERR_STATUS_INVALID"));

  json::Value gone = obj();
  gone.set("businessId", w.bizId);
  gone.set("appointmentId", "yok");
  gone.set("status", "cancelled");
  CHECK_EQ(w.call("appointment.setStatus", gone)["code"].asString(),
           std::string("ERR_APPOINTMENT_NOT_FOUND"));
}

TEST(apt_setStatus_baska_isletmenin_randevusuna_dokunamaz) {
  World w = makeWorld();
  const std::string other = join(*w.rt, "DUKKAN52", "Berber Veli", "business");
  const std::string id =
      w.call("appointment.create", bookPayload(w.bizId, slotAt(11)))["data"]["id"].asString();

  json::Value up = obj();
  up.set("businessId", other);
  up.set("appointmentId", id);
  up.set("status", "cancelled");
  CHECK_EQ(w.call("appointment.setStatus", up)["code"].asString(),
           std::string("ERR_APPOINTMENT_NOT_FOUND"));
}

// ─────────────────────────────────────────────────────────────────── müşteri

TEST(cus_create_ve_normalize) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("name", "  Şükrü Yılmaz  ");
  p.set("phone", "0532 111 22 33");
  p.set("email", "sukru@ornek.com");
  const json::Value r = w.call("customer.create", p);
  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["name"].asString(), std::string("Şükrü Yılmaz"));
  CHECK_EQ(r["data"]["phone"].asString(), std::string("+905321112233"));
  CHECK_EQ(r["data"]["visitCount"].asInt(), int64_t{0});
}

TEST(cus_create_hatali_girdiler) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("name", "   ");
  CHECK_EQ(w.call("customer.create", p)["code"].asString(),
           std::string("ERR_NAME_REQUIRED"));

  p.set("name", "Ali");
  p.set("phone", "123");
  CHECK_EQ(w.call("customer.create", p)["code"].asString(),
           std::string("ERR_INVALID_PHONE"));

  p.set("phone", "");
  p.set("email", "bozuk@");
  CHECK_EQ(w.call("customer.create", p)["code"].asString(),
           std::string("ERR_INVALID_EMAIL"));
}

TEST(cus_create_ayni_telefonu_iki_kez_kaydetmez) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("name", "Ali Veli");
  p.set("phone", "0532 111 22 33");
  CHECK(w.call("customer.create", p)["ok"].asBool());

  // Aynı numara farklı yazımla — yine aynı kişidir
  p.set("name", "Ali V.");
  p.set("phone", "+90 532 111 22 33");
  CHECK_EQ(w.call("customer.create", p)["code"].asString(),
           std::string("ERR_CUSTOMER_EXISTS"));

  // Telefonsuz kayıtlar tekillik kuralına takılmaz
  json::Value q = obj();
  q.set("businessId", w.bizId);
  q.set("name", "Telefonsuz Biri");
  CHECK(w.call("customer.create", q)["ok"].asBool());
  q.set("name", "Baska Telefonsuz");
  CHECK(w.call("customer.create", q)["ok"].asBool());
}

TEST(cus_list_ada_gore_sirali_ve_aranabilir) {
  World w = makeWorld();
  for (const char* n : {"Zeynep Ak", "Ahmet Kaya", "Şükrü Yılmaz"}) {
    json::Value p = obj();
    p.set("businessId", w.bizId);
    p.set("name", n);
    w.call("customer.create", p);
  }

  json::Value all = obj();
  all.set("businessId", w.bizId);
  const json::Value res5 = w.call("customer.list", all);
  const auto& items = res5["data"]["items"].asArray();
  CHECK_EQ(items.size(), size_t{3});
  CHECK_EQ(at(items, 0)["name"].asString(), std::string("Ahmet Kaya"));
  CHECK_EQ(at(items, 1)["name"].asString(), std::string("Şükrü Yılmaz"));
  CHECK_EQ(at(items, 2)["name"].asString(), std::string("Zeynep Ak"));

  json::Value q = obj();
  q.set("businessId", w.bizId);
  q.set("query", "SUKRU");
  const json::Value r = w.call("customer.list", q);
  CHECK_EQ(r["data"]["items"].asArray().size(), size_t{1});
  CHECK_EQ(r["data"]["total"].asInt(), int64_t{1});
}

TEST(cus_list_limit_uygular_ama_toplami_bildirir) {
  World w = makeWorld();
  for (int i = 0; i < 5; ++i) {
    json::Value p = obj();
    p.set("businessId", w.bizId);
    p.set("name", "Musteri " + std::to_string(i));
    w.call("customer.create", p);
  }
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("limit", 2);
  const json::Value r = w.call("customer.list", p);
  CHECK_EQ(r["data"]["items"].asArray().size(), size_t{2});
  CHECK_EQ(r["data"]["total"].asInt(), int64_t{5});
}

TEST(cus_update_yalnizca_verilen_alani_degistirir) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("name", "Ali Veli");
  p.set("phone", "0532 111 22 33");
  p.set("note", "ilk not");
  const std::string id = w.call("customer.create", p)["data"]["id"].asString();

  json::Value up = obj();
  up.set("businessId", w.bizId);
  up.set("customerId", id);
  up.set("note", "guncel not");
  const json::Value r = w.call("customer.update", up);
  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["note"].asString(), std::string("guncel not"));
  CHECK_EQ(r["data"]["name"].asString(), std::string("Ali Veli"));       // dokunulmadı
  CHECK_EQ(r["data"]["phone"].asString(), std::string("+905321112233")); // dokunulmadı
}

TEST(cus_update_etiketleri_normalize_ederek_degistirir) {
  World w = makeWorld();
  json::Value p = obj();
  p.set("businessId", w.bizId);
  p.set("name", "Ali Veli");
  const std::string id = w.call("customer.create", p)["data"]["id"].asString();

  json::Value up = obj();
  up.set("businessId", w.bizId);
  up.set("customerId", id);
  json::Value tags = json::Value::arr();
  tags.push("VIP Müşteri");
  tags.push("Sadık");
  tags.push("vip-musteri");  // tekrar — elenir
  up.set("tags", tags);

  const json::Value res6 = w.call("customer.update", up);
  const auto& out = res6["data"]["tags"].asArray();
  CHECK_EQ(out.size(), size_t{2});
  CHECK_EQ(at(out, 0).asString(), std::string("vip-musteri"));
  CHECK_EQ(at(out, 1).asString(), std::string("sadik"));
}

TEST(cus_update_olmayan_kayit) {
  World w = makeWorld();
  json::Value up = obj();
  up.set("businessId", w.bizId);
  up.set("customerId", "yok");
  up.set("note", "x");
  CHECK_EQ(w.call("customer.update", up)["code"].asString(),
           std::string("ERR_CUSTOMER_NOT_FOUND"));
}

// ───────────────────────────────────── randevu tamamlanınca müşteri güncellenir

TEST(apt_tamamlaninca_musteri_ziyareti_islenir) {
  World w = makeWorld();
  json::Value c = obj();
  c.set("businessId", w.bizId);
  c.set("name", "Ali Veli");
  const std::string cusId = w.call("customer.create", c)["data"]["id"].asString();

  json::Value p = bookPayload(w.bizId, slotAt(11), "Ali Veli");
  p.set("customerId", cusId);
  p.set("priceKurus", 45000);
  const std::string aptId = w.call("appointment.create", p)["data"]["id"].asString();

  json::Value up = obj();
  up.set("businessId", w.bizId);
  up.set("appointmentId", aptId);
  up.set("status", "completed");
  CHECK(w.call("appointment.setStatus", up)["ok"].asBool());

  json::Value list = obj();
  list.set("businessId", w.bizId);
  const json::Value res7 = w.call("customer.list", list);
  const auto& items = res7["data"]["items"].asArray();
  CHECK_EQ(items.size(), size_t{1});
  CHECK_EQ(at(items, 0)["visitCount"].asInt(), int64_t{1});
  CHECK_EQ(at(items, 0)["totalSpendKurus"].asInt(), int64_t{45000});
  CHECK_EQ(at(items, 0)["lastVisitAt"].asInt(), slotAt(11));
}

TEST(apt_iptal_musteriyi_etkilemez) {
  World w = makeWorld();
  json::Value c = obj();
  c.set("businessId", w.bizId);
  c.set("name", "Ali Veli");
  const std::string cusId = w.call("customer.create", c)["data"]["id"].asString();

  json::Value p = bookPayload(w.bizId, slotAt(11), "Ali Veli");
  p.set("customerId", cusId);
  p.set("priceKurus", 45000);
  const std::string aptId = w.call("appointment.create", p)["data"]["id"].asString();

  json::Value up = obj();
  up.set("businessId", w.bizId);
  up.set("appointmentId", aptId);
  up.set("status", "cancelled");
  w.call("appointment.setStatus", up);

  json::Value list = obj();
  list.set("businessId", w.bizId);
  const json::Value res8 = w.call("customer.list", list);
  const auto& items = res8["data"]["items"].asArray();
  CHECK_EQ(items.size(), size_t{1});   // kayit gercekten duruyor
  CHECK_EQ(at(items, 0)["name"].asString(), std::string("Ali Veli"));
  CHECK_EQ(at(items, 0)["visitCount"].asInt(), int64_t{0});
  CHECK_EQ(at(items, 0)["totalSpendKurus"].asInt(), int64_t{0});
}
