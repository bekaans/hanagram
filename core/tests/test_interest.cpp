#include "algo/interest.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::algo;

namespace {

Signal mk(SignalKind k, std::vector<std::string> topics, const std::string& author = "a1") {
  Signal s;
  s.userId = "u1";
  s.itemId = "p1";
  s.authorId = author;
  s.topics = std::move(topics);
  s.kind = k;
  return s;
}

}  // namespace

TEST(ilgi_begeni_konuyu_yukseltir) {
  InterestProfile p;
  const int64_t t = 1'700'000'000'000;
  p.apply(mk(SignalKind::Like, {"guzellik"}), t);

  CHECK(p.topicWeight("guzellik") > 0.9);  // tek konu → normalize sonrası ~1
  CHECK_EQ(p.topicWeight("spor"), 0.0);
}

TEST(ilgi_gizle_sinyali_dusurur) {
  InterestProfile p;
  const int64_t t = 1'700'000'000'000;
  p.apply(mk(SignalKind::Like, {"guzellik"}), t);
  p.apply(mk(SignalKind::Like, {"spor"}), t);
  const double sporOnce = p.topicWeight("spor");

  p.apply(mk(SignalKind::Hide, {"spor"}), t);
  CHECK(p.topicWeight("spor") < sporOnce);
}

TEST(ilgi_cok_etiketli_icerik_paylastirir) {
  InterestProfile a;
  InterestProfile b;
  const int64_t t = 1'700'000'000'000;

  a.apply(mk(SignalKind::Like, {"guzellik"}), t);
  b.apply(mk(SignalKind::Like, {"guzellik", "moda", "icerik"}), t);

  // Tek etiketli beğeni, çok etiketliye göre o konuya daha çok ağırlık vermeli.
  CHECK(a.topicWeight("guzellik") > b.topicWeight("guzellik"));
}

TEST(ilgi_zaman_bozunumu_calisir) {
  InterestProfile p;
  const int64_t t0 = 1'700'000'000'000;
  p.apply(mk(SignalKind::Like, {"guzellik"}), t0);
  p.apply(mk(SignalKind::Like, {"spor"}), t0);

  // 60 gün sonra yeni bir spor sinyali gelirse spor öne geçmeli:
  // eski güzellik ilgisi bozunmuş olur.
  const int64_t t1 = t0 + 60LL * 24 * 3600 * 1000;
  p.apply(mk(SignalKind::Like, {"spor"}), t1);
  CHECK(p.topicWeight("spor") > p.topicWeight("guzellik"));
}

TEST(ilgi_kisa_sure_sayilmaz) {
  InterestProfile p;
  const int64_t t = 1'700'000'000'000;
  Signal s = mk(SignalKind::Dwell, {"guzellik"});
  s.dwellMs = 1000;  // 2 sn altı
  p.apply(s, t);
  CHECK_EQ(p.signalCount(), int64_t(0));
  CHECK_EQ(p.topicWeight("guzellik"), 0.0);
}

TEST(ilgi_uzun_sure_sayilir) {
  InterestProfile p;
  const int64_t t = 1'700'000'000'000;
  Signal s = mk(SignalKind::Dwell, {"guzellik"});
  s.dwellMs = 20000;
  p.apply(s, t);
  CHECK_EQ(p.signalCount(), int64_t(1));
  CHECK(p.topicWeight("guzellik") > 0.0);
}

TEST(ilgi_eslesme_skoru) {
  InterestProfile p;
  const int64_t t = 1'700'000'000'000;
  for (int i = 0; i < 5; i++) p.apply(mk(SignalKind::Like, {"guzellik"}), t);

  const double uyan = p.match({"guzellik"});
  const double uymayan = p.match({"insaat"});
  CHECK(uyan > uymayan);
  CHECK(uyan > 0.5);
  CHECK_EQ(uymayan, 0.0);
}

TEST(ilgi_guven_yeni_kullanicida_dusuk) {
  InterestProfile bos;
  CHECK_EQ(bos.confidence(), 0.0);

  InterestProfile p;
  const int64_t t = 1'700'000'000'000;
  for (int i = 0; i < 50; i++) p.apply(mk(SignalKind::Like, {"guzellik"}), t);
  CHECK(p.confidence() > 0.7);
}

TEST(ilgi_json_gidis_donus) {
  InterestProfile p;
  const int64_t t = 1'700'000'000'000;
  p.apply(mk(SignalKind::Save, {"medikal"}, "yazar9"), t);

  InterestProfile back = InterestProfile::fromJson(p.toJson());
  CHECK_NEAR(back.topicWeight("medikal"), p.topicWeight("medikal"), 1e-9);
  CHECK_NEAR(back.authorAffinity("yazar9"), p.authorAffinity("yazar9"), 1e-9);
  CHECK_EQ(back.signalCount(), p.signalCount());
}

TEST(sinyal_adlari_gidis_donus) {
  for (const char* n : {"view", "dwell", "like", "comment", "save", "share", "follow",
                        "profile_visit", "product_tap", "skip", "hide", "report"}) {
    SignalKind k;
    CHECK(signalFromName(n, k));
    CHECK_EQ(std::string(signalName(k)), std::string(n));
  }
  SignalKind k;
  CHECK(!signalFromName("olmayan", k));
}
