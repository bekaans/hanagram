// Reklam alanı testleri
#include "domain/business/ad.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::domain;

namespace {

Ad sample() {
  Ad a;
  a.id = "a1";
  a.businessId = "b1";
  a.title = "Yaz indirimi!";
  a.description = "Tüm kahvelerde %20 indirim";
  a.imageUrl = "https://example.com/ad.jpg";
  a.targetTopics = {"kahve", "yiyecek"};
  a.dailyBudgetKurus = 50000;
  a.bid = 1.5;
  a.status = AdStatus::kActive;
  a.impressions = 100;
  a.clicks = 10;
  a.createdAt = 1000;
  a.updatedAt = 1000;
  return a;
}

}  // namespace

// ── Durum ──

TEST(adStatus_gidis_donus) {
  CHECK_EQ(std::string(adStatusToString(AdStatus::kDraft)), std::string("draft"));
  CHECK_EQ(std::string(adStatusToString(AdStatus::kActive)), std::string("active"));
  CHECK_EQ(std::string(adStatusToString(AdStatus::kPaused)), std::string("paused"));
  CHECK_EQ(std::string(adStatusToString(AdStatus::kExpired)), std::string("expired"));
}

TEST(adStatus_fromString) {
  CHECK_EQ(adStatusFromString("draft"), AdStatus::kDraft);
  CHECK_EQ(adStatusFromString("active"), AdStatus::kActive);
  CHECK_EQ(adStatusFromString("paused"), AdStatus::kPaused);
  CHECK_EQ(adStatusFromString("expired"), AdStatus::kExpired);
  CHECK_EQ(adStatusFromString("bogus"), AdStatus::kDraft);
}

// ── Doğrulama ──

TEST(sanitizeAdTitle_normal) {
  CHECK_EQ(sanitizeAdTitle("Yaz indirimi!"), std::string("Yaz indirimi!"));
}

TEST(sanitizeAdTitle_bos_gecersiz) {
  CHECK(sanitizeAdTitle("").empty());
  CHECK(sanitizeAdTitle("   ").empty());
}

TEST(sanitizeAdTitle_basi_sondaki_bosluk) {
  CHECK_EQ(sanitizeAdTitle("  Başlık  "), std::string("Başlık"));
}

TEST(sanitizeAdDescription_normal) {
  CHECK_EQ(sanitizeAdDescription("Açıklama"), std::string("Açıklama"));
}

TEST(sanitizeAdDescription_bos_gecerli) {
  CHECK(sanitizeAdDescription("").empty());
}

// ── JSON ──

TEST(ad_json_donusumu) {
  Ad a = sample();
  json::Value j = a.toJson();
  Ad a2 = Ad::fromJson(j);
  CHECK_EQ(a2.id, a.id);
  CHECK_EQ(a2.title, a.title);
  CHECK_EQ(a2.businessId, a.businessId);
  CHECK_EQ(a2.dailyBudgetKurus, a.dailyBudgetKurus);
  CHECK_EQ(a2.status, a.status);
  CHECK_EQ(a2.impressions, a.impressions);
  CHECK_EQ(a2.targetTopics.size(), a.targetTopics.size());
}
