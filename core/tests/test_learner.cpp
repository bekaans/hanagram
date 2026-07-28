// Öğrenme katmanı testleri — "kendi kendini geliştiren" iddiasının kanıtı.
#include "algo/learner.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::algo;

namespace {

constexpr int64_t kNow = 1'700'000'000'000;

// Deterministik sözde-rastgele — test tekrar edilebilir olmalı.
struct Rng {
  uint64_t s = 12345;
  double next() {
    s = s * 6364136223846793005ULL + 1442695040888963407ULL;
    return static_cast<double>((s >> 33) % 10000) / 10000.0;
  }
};

// Gerçekliği "interest" belirleyen bir dünya kurar: etkileşim yalnızca ilgi
// bileşeniyle ilişkilidir, tazelik tamamen gürültüdür.
void feedWorldWhereInterestMatters(Learner& l, int n) {
  Rng rng;
  for (int i = 0; i < n; i++) {
    Impression imp;
    imp.userId = "u1";
    imp.itemId = "p" + std::to_string(i);
    imp.parts.interest = rng.next();
    imp.parts.freshness = rng.next();
    imp.parts.quality = rng.next();
    imp.parts.affinity = rng.next();
    imp.parts.following = rng.next() > 0.5 ? 1.0 : 0.0;
    imp.shownAt = kNow;
    l.recordImpression(imp);

    // Gerçek: yalnızca ilgi yüksekse etkileşim var.
    const bool engaged = imp.parts.interest > 0.6;
    l.recordOutcome("u1", imp.itemId, engaged, engaged ? 8000 : 500);
  }
}

}  // namespace

TEST(ogrenme_yetersiz_veriyle_dokunmaz) {
  Learner l;
  Weights w;
  const auto cal = l.calibrate(w, kNow);
  CHECK(!cal.applied);
  CHECK_EQ(cal.reason, std::string("yetersiz_veri"));
  CHECK(!l.ready());
}

TEST(ogrenme_gosterim_ve_sonuc_eslesir) {
  Learner l;
  Impression imp;
  imp.userId = "u1";
  imp.itemId = "p1";
  imp.parts.interest = 0.8;
  imp.shownAt = kNow;
  l.recordImpression(imp);

  CHECK_EQ(l.sampleSize(), size_t(0));
  l.recordOutcome("u1", "p1", true, 9000);
  CHECK_EQ(l.sampleSize(), size_t(1));
  CHECK_NEAR(l.engagementRate(), 1.0, 1e-9);
}

TEST(ogrenme_eslesmeyen_sonuc_yok_sayilir) {
  Learner l;
  l.recordOutcome("olmayan", "yok", true, 1000);
  CHECK_EQ(l.sampleSize(), size_t(0));
}

TEST(ogrenme_ise_yarayan_bilesenin_agirligini_artirir) {
  Learner l;
  feedWorldWhereInterestMatters(l, 400);
  CHECK(l.ready());

  Weights before;
  const auto cal = l.calibrate(before, kNow);

  CHECK(cal.applied);
  CHECK_EQ(cal.reason, std::string("iyilesme"));
  // Gerçekten öngören bileşen (interest) ağırlık kazanmalı.
  CHECK(cal.after.interest > cal.before.interest);
  // Gürültü olan bileşen (freshness) kaybetmeli.
  CHECK(cal.after.freshness < cal.before.freshness);
  // Tahmin hatası düşmeli.
  CHECK(cal.brierAfter < cal.brierBefore);
}

TEST(ogrenme_koruma_bandi_kotulesmeyi_engeller) {
  Learner l;
  // Tamamen rastgele dünya: hiçbir bileşen öngörmüyor.
  Rng rng;
  for (int i = 0; i < 300; i++) {
    Impression imp;
    imp.userId = "u1";
    imp.itemId = "p" + std::to_string(i);
    imp.parts.interest = rng.next();
    imp.parts.freshness = rng.next();
    imp.parts.quality = rng.next();
    imp.parts.affinity = rng.next();
    imp.parts.following = rng.next() > 0.5 ? 1.0 : 0.0;
    imp.shownAt = kNow;
    l.recordImpression(imp);
    l.recordOutcome("u1", imp.itemId, rng.next() > 0.5, 1000);
  }

  Weights before;
  const auto cal = l.calibrate(before, kNow);

  // Anlamlı iyileşme yoksa ağırlıklar DEĞİŞMEZ — sistem kendini bozamaz.
  if (!cal.applied) {
    CHECK_NEAR(cal.after.interest, before.interest, 1e-9);
    CHECK_NEAR(cal.after.freshness, before.freshness, 1e-9);
  }
  CHECK(cal.brierAfter <= cal.brierBefore + 1e-9);
}

TEST(ogrenme_agirliklar_normalize_kalir) {
  Learner l;
  feedWorldWhereInterestMatters(l, 400);
  Weights w;
  for (int round = 0; round < 12; round++) {
    const auto cal = l.calibrate(w, kNow);
    if (cal.applied) w = cal.after;
    const double sum =
        w.interest + w.freshness + w.quality + w.affinity + w.following;
    CHECK_NEAR(sum, 1.0, 1e-9);
    CHECK(w.interest <= 0.61);
    CHECK(w.freshness >= 0.04);
  }
}

TEST(ogrenme_tekrarli_kalibrasyon_iyilesmeyi_biriktirir) {
  Learner l;
  feedWorldWhereInterestMatters(l, 500);

  Weights w;
  const double ilkHata = l.brier(w);
  for (int round = 0; round < 8; round++) {
    const auto cal = l.calibrate(w, kNow);
    if (cal.applied) w = cal.after;
  }
  const double sonHata = l.brier(w);
  CHECK(sonHata < ilkHata);
}

TEST(ogrenme_pencere_sinirini_asmaz) {
  Learner l(50);
  for (int i = 0; i < 200; i++) {
    Impression imp;
    imp.userId = "u1";
    imp.itemId = "p" + std::to_string(i);
    imp.shownAt = kNow;
    l.recordImpression(imp);
    l.recordOutcome("u1", imp.itemId, i % 2 == 0, 100);
  }
  CHECK(l.impressions().size() <= size_t(50));
  CHECK(l.sampleSize() <= size_t(50));
}

TEST(ogrenme_kesif_verimi_olculur) {
  Learner l;
  for (int i = 0; i < 20; i++) {
    Impression imp;
    imp.userId = "u1";
    imp.itemId = "e" + std::to_string(i);
    imp.exploration = true;
    imp.shownAt = kNow;
    l.recordImpression(imp);
    l.recordOutcome("u1", imp.itemId, i < 5, 100);  // 5/20 tuttu
  }
  CHECK_NEAR(l.explorationYield(), 0.25, 1e-9);
}

TEST(ogrenme_json_gidis_donus) {
  Learner l;
  feedWorldWhereInterestMatters(l, 30);

  Learner geri;
  geri.loadJson(l.toJson());
  CHECK_EQ(geri.sampleSize(), l.sampleSize());
  CHECK_NEAR(geri.engagementRate(), l.engagementRate(), 1e-9);
}
