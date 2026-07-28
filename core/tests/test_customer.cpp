// Müşteri (CRM) testleri — SÖZLEŞME. Ajan bu dosyayı DEĞİŞTİREMEZ.
// Görev: bu testleri geçiren domain/business/customer.cpp dosyasını yazmak.
#include "domain/business/customer.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::domain;

namespace {

std::string phone(const std::string& raw) {
  std::string out = "<cagrilmadi>";
  return normalizePhone(raw, out) ? out : std::string("<gecersiz>");
}

Customer sample() {
  Customer c;
  c.id = "c1";
  c.businessId = "b1";
  c.name = "Şükrü Yılmaz";
  c.phone = "+905321112233";
  return c;
}

}  // namespace

// ────────────────────────────────────────────────────────────────── telefon

TEST(normalizePhone_turkiye_bicimleri_ayni_sonuca_iner) {
  const std::string want = "+905321112233";
  CHECK_EQ(phone("0532 111 22 33"), want);
  CHECK_EQ(phone("(0532) 111-22-33"), want);
  CHECK_EQ(phone("05321112233"), want);
  CHECK_EQ(phone("90 532 111 22 33"), want);
  CHECK_EQ(phone("+90 532 111 22 33"), want);
  CHECK_EQ(phone("+905321112233"), want);
  CHECK_EQ(phone("5321112233"), want);
}

TEST(normalizePhone_sabit_hat) {
  CHECK_EQ(phone("0212 555 44 33"), std::string("+902125554433"));
}

TEST(normalizePhone_yabanci_numara_ulke_kodunu_korur) {
  CHECK_EQ(phone("+1 (555) 123-4567"), std::string("+15551234567"));
  CHECK_EQ(phone("+49 30 12345678"), std::string("+493012345678"));
}

TEST(normalizePhone_bos_girdi_gecerlidir) {
  std::string out = "dolu";
  CHECK(normalizePhone("", out));
  CHECK_EQ(out, std::string(""));

  out = "dolu";
  CHECK(normalizePhone("   ", out));
  CHECK_EQ(out, std::string(""));
}

TEST(normalizePhone_gecersizler) {
  CHECK_EQ(phone("123"), std::string("<gecersiz>"));
  CHECK_EQ(phone("abc"), std::string("<gecersiz>"));
  // 10 rakam ama sıfırla başlıyor — ne 11'lik ne 10'luk kalıba uyar
  CHECK_EQ(phone("0532111223"), std::string("<gecersiz>"));
  // '+' yok ve hiçbir Türkiye kalıbına uymuyor
  CHECK_EQ(phone("15551234567"), std::string("<gecersiz>"));
  // E.164 üst sınırı 15 rakam
  CHECK_EQ(phone("+1234567890123456"), std::string("<gecersiz>"));
}

TEST(normalizePhone_gecersizde_cikisa_dokunmaz) {
  std::string out = "onceki";
  CHECK(!normalizePhone("123", out));
  CHECK_EQ(out, std::string("onceki"));
}

// ──────────────────────────────────────────────────────────── arama katlama

TEST(foldForSearch_turkce_harfleri_asciye_indirir) {
  CHECK_EQ(foldForSearch("Şükrü"), std::string("sukru"));
  CHECK_EQ(foldForSearch("İSTANBUL"), std::string("istanbul"));
  CHECK_EQ(foldForSearch("Çağrı"), std::string("cagri"));
  CHECK_EQ(foldForSearch("GÖZDE"), std::string("gozde"));
  CHECK_EQ(foldForSearch("ĞÜŞİÖÇ"), std::string("gusioc"));
  CHECK_EQ(foldForSearch("ğüşıöç"), std::string("gusioc"));
}

TEST(foldForSearch_bosluklari_duzenler) {
  CHECK_EQ(foldForSearch("  Ali   Veli  "), std::string("ali veli"));
  CHECK_EQ(foldForSearch(""), std::string(""));
  CHECK_EQ(foldForSearch("   "), std::string(""));
  CHECK_EQ(foldForSearch("\tAhmet\n"), std::string("ahmet"));
}

TEST(foldForSearch_ascii_aynen_kucultur) {
  CHECK_EQ(foldForSearch("Ahmet Mehmet"), std::string("ahmet mehmet"));
  CHECK_EQ(foldForSearch("ABC123"), std::string("abc123"));
}

// ───────────────────────────────────────────────────────────── ad ve eposta

TEST(sanitizeName_kirpar) {
  std::string out;
  CHECK(sanitizeName("  Ali Veli  ", out));
  CHECK_EQ(out, std::string("Ali Veli"));

  CHECK(sanitizeName(std::string(200, 'x'), out));
  CHECK_EQ(out.size(), kMaxNameLength);
}

TEST(sanitizeName_bos_ad_gecersizdir) {
  std::string out = "onceki";
  CHECK(!sanitizeName("", out));
  CHECK_EQ(out, std::string("onceki"));
  CHECK(!sanitizeName("   ", out));
  CHECK_EQ(out, std::string("onceki"));
}

TEST(isValidEmail_kabul_ve_ret) {
  CHECK(isValidEmail(""));  // zorunlu alan değil
  CHECK(isValidEmail("a@b.co"));
  CHECK(isValidEmail("ali.veli@ornek.com.tr"));

  CHECK(!isValidEmail("a@b"));
  CHECK(!isValidEmail("@b.co"));
  CHECK(!isValidEmail("a@"));
  CHECK(!isValidEmail("a@.co"));
  CHECK(!isValidEmail("a@b.co."));
  CHECK(!isValidEmail("a b@c.co"));
  CHECK(!isValidEmail("a@@b.co"));
  CHECK(!isValidEmail("ab.co"));
}

// ───────────────────────────────────────────────────────────────── etiketler

TEST(normalizeTag_katlar_ve_tireler) {
  std::string out;
  CHECK(normalizeTag("VIP Müşteri", out));
  CHECK_EQ(out, std::string("vip-musteri"));

  CHECK(normalizeTag("  Sadık   Müşteri ", out));
  CHECK_EQ(out, std::string("sadik-musteri"));
}

TEST(normalizeTag_bos_gecersizdir) {
  std::string out = "onceki";
  CHECK(!normalizeTag("", out));
  CHECK(!normalizeTag("   ", out));
  CHECK_EQ(out, std::string("onceki"));
}

TEST(addTag_tekrari_engeller) {
  Customer c = sample();
  CHECK(addTag(c, "VIP"));
  CHECK_EQ(c.tags.size(), size_t{1});
  CHECK_EQ(c.tags[0], std::string("vip"));

  // Aynı etiket farklı yazımla — yine de tekrardır
  CHECK(!addTag(c, "vip"));
  CHECK(!addTag(c, "  VİP  "));
  CHECK_EQ(c.tags.size(), size_t{1});
}

TEST(addTag_sinira_kadar) {
  Customer c = sample();
  for (size_t i = 0; i < kMaxTags; ++i) {
    CHECK(addTag(c, "etiket" + std::to_string(i)));
  }
  CHECK_EQ(c.tags.size(), kMaxTags);
  CHECK(!addTag(c, "birdaha"));
  CHECK_EQ(c.tags.size(), kMaxTags);
}

TEST(hasTag_ve_removeTag) {
  Customer c = sample();
  addTag(c, "VIP Müşteri");
  CHECK(hasTag(c, "vip-musteri"));
  CHECK(hasTag(c, "VIP Müşteri"));
  CHECK(!hasTag(c, "yok"));

  CHECK(removeTag(c, "VIP MÜŞTERİ"));
  CHECK(c.tags.empty());
  CHECK(!removeTag(c, "vip-musteri"));
}

// ─────────────────────────────────────────────────────────────────── arama

TEST(matchesQuery_bos_sorgu_hepsine_uyar) {
  const Customer c = sample();
  CHECK(matchesQuery(c, ""));
  CHECK(matchesQuery(c, "   "));
}

TEST(matchesQuery_ad_turkce_duyarsiz) {
  const Customer c = sample();
  CHECK(matchesQuery(c, "sukru"));
  CHECK(matchesQuery(c, "ŞÜKRÜ"));
  CHECK(matchesQuery(c, "yilmaz"));
  CHECK(matchesQuery(c, "Yılmaz"));
  CHECK(!matchesQuery(c, "ahmet"));
}

TEST(matchesQuery_telefon_yalnizca_rakamlara_bakar) {
  const Customer c = sample();
  CHECK(matchesQuery(c, "532 111"));
  CHECK(matchesQuery(c, "5321112233"));
  CHECK(matchesQuery(c, "+90 532"));
  CHECK(!matchesQuery(c, "999 888"));
}

TEST(matchesQuery_telefonsuz_kayitta_cakmaz) {
  Customer c = sample();
  c.phone.clear();
  CHECK(!matchesQuery(c, "532"));
  CHECK(matchesQuery(c, "sukru"));
}

// ──────────────────────────────────────────────────────────────── ziyaretler

TEST(recordVisit_sayaclari_arttirir) {
  Customer c = sample();
  recordVisit(c, 1000, 45000);
  CHECK_EQ(c.visitCount, int64_t{1});
  CHECK_EQ(c.lastVisitAt, int64_t{1000});
  CHECK_EQ(c.totalSpendKurus, int64_t{45000});

  recordVisit(c, 2000, 30000);
  CHECK_EQ(c.visitCount, int64_t{2});
  CHECK_EQ(c.lastVisitAt, int64_t{2000});
  CHECK_EQ(c.totalSpendKurus, int64_t{75000});
}

TEST(recordVisit_son_ziyaret_geri_gitmez) {
  Customer c = sample();
  recordVisit(c, 5000, 10000);
  recordVisit(c, 1000, 10000);  // geçmişe dönük giriş
  CHECK_EQ(c.visitCount, int64_t{2});
  CHECK_EQ(c.lastVisitAt, int64_t{5000});  // geri alınmaz
  CHECK_EQ(c.totalSpendKurus, int64_t{20000});
}

// ───────────────────────────────────────────────────────────────────── json

TEST(customer_json_gidis_donus) {
  Customer c = sample();
  c.email = "sukru@ornek.com";
  c.note = "sabah saatlerini tercih ediyor";
  c.linkedUserId = "u9";
  c.createdAt = 111;
  c.lastVisitAt = 222;
  c.visitCount = 3;
  c.totalSpendKurus = 90000;
  addTag(c, "VIP");
  addTag(c, "Sadık");

  const Customer b = Customer::fromJson(c.toJson());
  CHECK_EQ(b.id, c.id);
  CHECK_EQ(b.businessId, c.businessId);
  CHECK_EQ(b.name, c.name);
  CHECK_EQ(b.phone, c.phone);
  CHECK_EQ(b.email, c.email);
  CHECK_EQ(b.note, c.note);
  CHECK_EQ(b.linkedUserId, c.linkedUserId);
  CHECK_EQ(b.createdAt, c.createdAt);
  CHECK_EQ(b.lastVisitAt, c.lastVisitAt);
  CHECK_EQ(b.visitCount, c.visitCount);
  CHECK_EQ(b.totalSpendKurus, c.totalSpendKurus);
  CHECK_EQ(b.tags.size(), size_t{2});
  CHECK_EQ(b.tags[0], std::string("vip"));
  CHECK_EQ(b.tags[1], std::string("sadik"));
}

TEST(customer_fromJson_eksik_alanda_varsayilana_duser) {
  const Customer c = Customer::fromJson(json::Value::obj());
  CHECK(c.name.empty());
  CHECK(c.tags.empty());
  CHECK_EQ(c.visitCount, int64_t{0});
  CHECK_EQ(c.totalSpendKurus, int64_t{0});
}
