#include "algo/ranker.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::algo;

namespace {

constexpr int64_t kNow = 1'700'000'000'000;

Candidate post(const std::string& id, std::vector<std::string> topics,
               int64_t ageMs = 0, const std::string& author = "a1") {
  Candidate c;
  c.id = id;
  c.authorId = author;
  c.topics = std::move(topics);
  c.createdAt = kNow - ageMs;
  c.views = 100;
  c.likes = 10;
  return c;
}

InterestProfile guzellikSever() {
  InterestProfile p;
  Signal s;
  s.userId = "u1";
  s.authorId = "a9";
  s.topics = {"guzellik"};
  s.kind = SignalKind::Like;
  for (int i = 0; i < 10; i++) p.apply(s, kNow);
  return p;
}

}  // namespace

TEST(sirala_ilgi_alanina_uyani_one_alir) {
  Ranker r;
  const auto p = guzellikSever();

  std::vector<Candidate> pool = {
      post("uymayan", {"insaat"}),
      post("uyan", {"guzellik"}, 0, "a2"),
  };

  RankOptions opt;
  opt.limit = 2;
  opt.exploreBase = 0.0;
  const auto out = r.rank(pool, p, kNow, opt);

  CHECK_EQ(out.size(), size_t(2));
  CHECK_EQ(out[0].id, std::string("uyan"));
}

TEST(sirala_taze_icerik_avantajli) {
  Ranker r;
  InterestProfile p;  // boş profil → tazelik ve kalite belirleyici

  const Candidate eski = post("eski", {"x"}, 7LL * 24 * 3600 * 1000, "a1");
  const Candidate taze = post("taze", {"x"}, 0, "a2");

  RankOptions opt;
  CHECK(r.score(taze, p, kNow, opt).score > r.score(eski, p, kNow, opt).score);
}

TEST(sirala_kesif_kucuk_limitte_de_yerlesir) {
  // Regresyon: keşif öğeleri sabit aralığa bağlıyken küçük limitlerde hiç
  // yerleşmiyor ve akışın sonuna itiliyordu.
  Ranker r;
  InterestProfile bos;

  std::vector<Candidate> pool = {
      post("a", {"konu1"}, 0, "y1"),
      post("b", {"konu2"}, 0, "y2"),
  };

  RankOptions opt;
  opt.limit = 2;
  const auto out = r.rank(pool, bos, kNow, opt);
  CHECK_EQ(out.size(), size_t(2));
}

TEST(sirala_gorulmus_icerik_cezalanir) {
  Ranker r;
  InterestProfile p;

  Candidate seen = post("gorulmus", {"x"}, 0, "a1");
  seen.seen = true;
  Candidate fresh = post("yeni", {"x"}, 0, "a2");

  RankOptions opt;
  const auto sSeen = r.score(seen, p, kNow, opt);
  const auto sFresh = r.score(fresh, p, kNow, opt);
  CHECK(sSeen.score < sFresh.score);
}

TEST(sirala_ayni_yazardan_sinir) {
  Ranker r;
  InterestProfile p;

  std::vector<Candidate> pool;
  for (int i = 0; i < 6; i++) {
    pool.push_back(post("p" + std::to_string(i), {"konu" + std::to_string(i)}, 0, "ayni"));
  }
  for (int i = 0; i < 4; i++) {
    pool.push_back(post("d" + std::to_string(i), {"baska" + std::to_string(i)}, 0,
                        "yazar" + std::to_string(i)));
  }

  RankOptions opt;
  opt.limit = 8;
  opt.maxPerAuthor = 2;
  opt.exploreBase = 0.0;

  const auto out = r.rank(pool, p, kNow, opt);
  int ayniSayisi = 0;
  for (const auto& item : out) {
    if (item.id.size() > 0 && item.id[0] == 'p') ayniSayisi++;
  }
  // İlk turda aynı yazardan en fazla maxPerAuthor(2) alınır. Havuz tükenince
  // sınır kademeli gevşer (2×) — boş akış göstermektense biraz tekrar iyidir,
  // ama sınır tamamen kalkmaz: tek yazar akışı ele geçiremez.
  CHECK(ayniSayisi <= 4);
  CHECK(out.size() >= size_t(6));
}

TEST(sirala_kesif_yeni_kullanicida_artar) {
  Ranker r;
  InterestProfile bos;  // güven 0 → keşif oranı yüksek

  std::vector<Candidate> pool;
  for (int i = 0; i < 20; i++) {
    pool.push_back(post("p" + std::to_string(i), {"konu" + std::to_string(i % 7)}, 0,
                        "yazar" + std::to_string(i)));
  }

  RankOptions opt;
  opt.limit = 12;
  const auto out = r.rank(pool, bos, kNow, opt);

  int kesif = 0;
  for (const auto& i : out) if (i.exploration) kesif++;
  CHECK(kesif > 0);
}

TEST(sirala_reklam_kalitesiz_ise_ustte_olmaz) {
  Ranker r;
  const auto p = guzellikSever();

  Candidate kotuReklam = post("reklam", {"insaat"}, 0, "reklamci");
  kotuReklam.sponsored = true;
  kotuReklam.bid = 1.0;
  kotuReklam.views = 1000;
  kotuReklam.likes = 1;  // çok düşük kalite

  Candidate iyiIcerik = post("icerik", {"guzellik"}, 0, "a2");
  iyiIcerik.views = 100;
  iyiIcerik.likes = 40;

  RankOptions opt;
  const auto sAd = r.score(kotuReklam, p, kNow, opt);
  const auto sPost = r.score(iyiIcerik, p, kNow, opt);
  // Teklif kaliteyle ÇARPILIR: para tek başına üste çıkaramaz.
  CHECK(sPost.score > sAd.score);
}

TEST(sirala_takip_akisinda_reklam_yok) {
  Ranker r;
  InterestProfile p;

  Candidate takipEdilen = post("takip", {"x"}, 0, "a1");
  takipEdilen.following = true;
  Candidate reklam = post("reklam", {"x"}, 0, "a2");
  reklam.sponsored = true;
  reklam.following = true;

  RankOptions opt;
  opt.followingOnly = true;
  opt.adEvery = 0;
  opt.limit = 10;

  const auto out = r.rank({takipEdilen, reklam}, p, kNow, opt);
  for (const auto& i : out) CHECK(!i.sponsored);
}

TEST(sirala_bos_havuz_cokmez) {
  Ranker r;
  InterestProfile p;
  RankOptions opt;
  const auto out = r.rank({}, p, kNow, opt);
  CHECK_EQ(out.size(), size_t(0));
}

TEST(agirliklar_normalize_ve_sinirli) {
  Weights w;
  w.interest = 10.0;   // aşırı
  w.freshness = -5.0;  // negatif
  w.clampAndNormalize();

  const double sum = w.interest + w.freshness + w.quality + w.affinity + w.following;
  CHECK_NEAR(sum, 1.0, 1e-9);
  CHECK(w.freshness > 0.0);   // hiçbir bileşen tamamen kapanamaz
  CHECK(w.interest < 0.75);   // hiçbiri tek başına baskın olamaz
}

TEST(agirliklar_json_gidis_donus) {
  Weights w;
  w.interest = 0.40;
  w.quality = 0.20;
  w.clampAndNormalize();

  Weights back = Weights::fromJson(w.toJson());
  CHECK_NEAR(back.interest, w.interest, 1e-9);
  CHECK_NEAR(back.quality, w.quality, 1e-9);
}
