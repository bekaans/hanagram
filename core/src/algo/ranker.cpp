#include "ranker.hpp"

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <unordered_set>

namespace hg::algo {

json::Value Weights::toJson() const {
  json::Value v = json::Value::obj();
  v.set("interest", interest);
  v.set("freshness", freshness);
  v.set("quality", quality);
  v.set("affinity", affinity);
  v.set("following", following);
  return v;
}

Weights Weights::fromJson(const json::Value& v) {
  Weights w;
  if (v.has("interest")) w.interest = v["interest"].asNumber(w.interest);
  if (v.has("freshness")) w.freshness = v["freshness"].asNumber(w.freshness);
  if (v.has("quality")) w.quality = v["quality"].asNumber(w.quality);
  if (v.has("affinity")) w.affinity = v["affinity"].asNumber(w.affinity);
  if (v.has("following")) w.following = v["following"].asNumber(w.following);
  w.clampAndNormalize();
  return w;
}

void Weights::clampAndNormalize() {
  // Hiçbir bileşen tamamen kapanamaz veya tek başına baskın olamaz.
  // Bu, öğrenmenin sistemi bozmasına karşı yapısal koruma (docs/03-algoritma.md §5).
  //
  // Dikkat: sadece "clamp sonra normalize" yetmez — normalize, clamp sınırını
  // yeniden aşabilir (ör. 0.60 + 4×0.05 = 0.80 → 0.60/0.80 = 0.75). Bu yüzden
  // sınır normalize edilmiş uzayda, sabit noktaya kadar uygulanır.
  // Yöntem: sınıra dayanan bileşenler sabitlenir, kalanlar KALAN bütçeye
  // orantılı dağıtılır ("bounded water-filling"). Basit clamp+normalize döngüsü
  // salınıma girer ve toplam asla tam 1 olmaz; bu yöntem sonlu adımda yakınsar.
  constexpr int kN = 5;
  double* ws[kN] = {&interest, &freshness, &quality, &affinity, &following};
  bool pinned[kN] = {false, false, false, false, false};

  for (double* w : ws) {
    if (!(*w > 0.0)) *w = kMinWeight;  // negatif ve NaN'ı temizler
  }

  for (int iter = 0; iter < kN + 1; iter++) {
    double pinnedSum = 0.0;
    double freeSum = 0.0;
    int freeCount = 0;
    for (int i = 0; i < kN; i++) {
      if (pinned[i]) {
        pinnedSum += *ws[i];
      } else {
        freeSum += *ws[i];
        freeCount++;
      }
    }
    if (freeCount == 0 || freeSum <= 0.0) break;

    const double budget = 1.0 - pinnedSum;
    if (budget <= 0.0) break;

    bool changed = false;
    for (int i = 0; i < kN; i++) {
      if (pinned[i]) continue;
      double v = *ws[i] / freeSum * budget;
      if (v < kMinWeight) {
        v = kMinWeight;
        pinned[i] = true;
        changed = true;
      } else if (v > kMaxWeight) {
        v = kMaxWeight;
        pinned[i] = true;
        changed = true;
      }
      *ws[i] = v;
    }
    if (!changed) return;  // dağıtım sınırlara dokunmadı: toplam tam olarak 1
  }

  // Ulaşılamaz olması beklenen kenar durum (tüm bileşenler sınıra dayandı):
  // yine de geçerli bir dağılım döndür.
  double sum = 0.0;
  for (double* w : ws) sum += *w;
  if (sum > 0.0) {
    for (double* w : ws) *w /= sum;
  } else {
    *this = Weights{};
  }
}

namespace {

// Kalite: etkileşim oranı, ama görüntüleme sayısı düşükken güvenilmez.
// Wilson alt sınırı benzeri bir yaklaşım: az veriyle yüksek oran cezalandırılır.
double qualityOf(const Candidate& c) {
  const double views = static_cast<double>(std::max<int64_t>(c.views, 1));
  const double engaged = static_cast<double>(c.likes) +
                         static_cast<double>(c.comments) * 2.0 +
                         static_cast<double>(c.shares) * 3.0;
  const double rate = engaged / views;
  // Güven katsayısı: 200 görüntülemede ~0.9'a yaklaşır.
  const double confidence = views / (views + 25.0);
  return std::clamp(rate * confidence, 0.0, 1.0);
}

double freshnessOf(const Candidate& c, int64_t now) {
  if (c.createdAt <= 0) return 0.0;
  const double age = static_cast<double>(std::max<int64_t>(now - c.createdAt, 0));
  return std::pow(0.5, age / static_cast<double>(kFreshnessHalfLifeMs));
}

// Deterministik sözde-rastgele: aynı kullanıcı+öğe için hep aynı değer.
// Keşif seçiminin her yenilemede zıplamaması için gerekli.
double stableJitter(const std::string& a, const std::string& b) {
  uint64_t h = 1469598103934665603ULL;
  for (char ch : a) h = (h ^ static_cast<unsigned char>(ch)) * 1099511628211ULL;
  for (char ch : b) h = (h ^ static_cast<unsigned char>(ch)) * 1099511628211ULL;
  return static_cast<double>(h % 10000) / 10000.0;
}

}  // namespace

ScoredItem Ranker::score(const Candidate& c, const InterestProfile& p, int64_t now,
                         const RankOptions& opt) const {
  ScoredItem s;
  s.id = c.id;
  s.sponsored = c.sponsored;

  s.parts.interest = p.match(c.topics);
  s.parts.freshness = freshnessOf(c, now);
  s.parts.quality = qualityOf(c);
  s.parts.affinity = p.authorAffinity(c.authorId);
  s.parts.following = c.following ? 1.0 : 0.0;

  double base = w_.interest * s.parts.interest +
                w_.freshness * s.parts.freshness +
                w_.quality * s.parts.quality +
                w_.affinity * s.parts.affinity +
                w_.following * s.parts.following;

  // Tahmini etkileşim olasılığı: ağırlıklar normalize olduğu için base zaten 0..1.
  // Öğrenme katmanı bu tahmini gerçek sonuçla karşılaştırır.
  s.predicted = std::clamp(base, 0.0, 1.0);

  if (c.seen) {
    const double before = base;
    base *= opt.seenPenalty;
    s.parts.penalty = base - before;
  }

  // Reklam: teklif skoru kaliteyle ÇARPILIR, yerine geçmez.
  // Kötü reklam para verse de üste çıkamaz — tüketici odaklılığın yapısal karşılığı.
  if (c.sponsored) {
    base = base * 0.55 + std::clamp(c.bid, 0.0, 1.0) * 0.45 * s.parts.quality;
  }

  s.score = base;
  return s;
}

std::vector<ScoredItem> Ranker::rank(const std::vector<Candidate>& pool,
                                     const InterestProfile& profile,
                                     int64_t now,
                                     const RankOptions& opt) const {
  std::vector<ScoredItem> scored;
  std::vector<const Candidate*> refs;
  scored.reserve(pool.size());
  refs.reserve(pool.size());

  for (const auto& c : pool) {
    if (opt.followingOnly && !c.following) continue;
    if (c.sponsored && opt.adEvery <= 0) continue;
    scored.push_back(score(c, profile, now, opt));
    refs.push_back(&c);
  }
  if (scored.empty()) return {};

  // ——— Keşif kotası ———
  // Profil ne kadar belirsizse o kadar çok keşif. Yeni kullanıcıda ~%45,
  // oturmuş profilde ~%15. Sistem kendi tahminini burada test eder.
  const double conf = profile.confidence();
  const double exploreRate = std::clamp(opt.exploreBase + (1.0 - conf) * 0.30, 0.05, 0.50);
  const int exploreSlots = static_cast<int>(std::round(opt.limit * exploreRate));

  // Sıralama indeksleri
  std::vector<size_t> idx(scored.size());
  for (size_t i = 0; i < idx.size(); i++) idx[i] = i;

  std::sort(idx.begin(), idx.end(), [&](size_t a, size_t b) {
    if (scored[a].score != scored[b].score) return scored[a].score > scored[b].score;
    return scored[a].id > scored[b].id;  // eşitlikte yeni olan (ULID sıralı)
  });

  // Keşif adayları: skoru düşük ama kullanıcının profilinde OLMAYAN konulardan.
  // Amaç rastgelelik değil — henüz bilinmeyen ilgi alanını yoklamak.
  std::vector<size_t> exploreIdx;
  if (exploreSlots > 0) {
    std::vector<size_t> unknown;
    for (size_t i : idx) {
      const Candidate& c = *refs[i];
      if (c.sponsored || c.seen) continue;
      bool known = false;
      for (const auto& t : c.topics) {
        if (profile.topicWeight(t) > 0.02) {
          known = true;
          break;
        }
      }
      if (!known) unknown.push_back(i);
    }
    // Kalite ve tazelik yüksek olanlar önce — keşif "çöp göster" demek değil.
    std::sort(unknown.begin(), unknown.end(), [&](size_t a, size_t b) {
      const double qa = scored[a].parts.quality * 0.6 + scored[a].parts.freshness * 0.4;
      const double qb = scored[b].parts.quality * 0.6 + scored[b].parts.freshness * 0.4;
      if (qa != qb) return qa > qb;
      return stableJitter(profile.toJson().dump().substr(0, 8), scored[a].id) >
             stableJitter(profile.toJson().dump().substr(0, 8), scored[b].id);
    });
    for (size_t i = 0; i < unknown.size() && static_cast<int>(exploreIdx.size()) < exploreSlots;
         i++) {
      exploreIdx.push_back(unknown[i]);
    }
  }
  std::unordered_set<size_t> isExplore(exploreIdx.begin(), exploreIdx.end());
  for (size_t i : exploreIdx) scored[i].exploration = true;

  // ——— Çeşitlilik + yerleştirme ———
  std::vector<ScoredItem> out;
  out.reserve(static_cast<size_t>(opt.limit));

  std::unordered_map<std::string, int> authorCount;
  std::unordered_map<std::string, int> topicCount;
  std::unordered_set<size_t> used;

  auto lastTopics = std::vector<std::string>{};
  size_t exploreCursor = 0;
  int sinceAd = 0;

  // authorLimit: aynı yazardan en fazla kaç öğe. checkTopics: ardışık konu bastırma.
  auto tryTake = [&](size_t i, int authorLimit, bool checkTopics) -> bool {
    if (used.count(i)) return false;
    const Candidate& c = *refs[i];
    if (c.sponsored) return false;  // reklamlar ayrı yuvadan gelir

    if (authorLimit > 0 && authorCount[c.authorId] >= authorLimit) return false;

    // Ardışık aynı konu bastırma: son öğeyle tam örtüşüyorsa atla.
    if (checkTopics && !lastTopics.empty() && !c.topics.empty()) {
      bool identical = c.topics.size() == lastTopics.size();
      if (identical) {
        for (size_t k = 0; k < c.topics.size(); k++) {
          if (c.topics[k] != lastTopics[k]) {
            identical = false;
            break;
          }
        }
      }
      if (identical) return false;
    }

    ScoredItem item = scored[i];
    item.parts.diversity = (authorLimit == opt.maxPerAuthor && checkTopics) ? 1.0 : 0.0;
    out.push_back(item);
    used.insert(i);
    authorCount[c.authorId]++;
    for (const auto& t : c.topics) topicCount[t]++;
    lastTopics = c.topics;
    sinceAd++;
    return true;
  };

  // Keşif öğeleri akışa eşit aralıklarla serpiştirilir. Aralık limite göre
  // hesaplanır; sabit bir sayı kullanılsaydı küçük limitlerde keşif hiç yerleşmezdi.
  const int exploreSpacing =
      exploreIdx.empty()
          ? 0
          : std::max(1, opt.limit / (static_cast<int>(exploreIdx.size()) + 1));

  while (static_cast<int>(out.size()) < opt.limit) {
    // Reklam yuvası
    if (opt.adEvery > 0 && sinceAd >= opt.adEvery) {
      size_t bestAd = SIZE_MAX;
      double bestScore = -1.0;
      for (size_t i : idx) {
        if (used.count(i) || !refs[i]->sponsored) continue;
        if (scored[i].score > bestScore) {
          bestScore = scored[i].score;
          bestAd = i;
        }
      }
      if (bestAd != SIZE_MAX) {
        out.push_back(scored[bestAd]);
        used.insert(bestAd);
        sinceAd = 0;
        continue;
      }
      sinceAd = 0;  // gösterilecek reklam yoksa sayaç sıfırlanır, akış aksamaz
    }

    // Keşif yuvası
    bool placed = false;
    if (exploreCursor < exploreIdx.size() && exploreSpacing > 0 &&
        (static_cast<int>(out.size()) + 1) % exploreSpacing == 0) {
      placed = tryTake(exploreIdx[exploreCursor], opt.maxPerAuthor, true);
      exploreCursor++;  // yerleşmese de ilerle: aynı öğede takılıp kalmayalım
    }
    if (placed) continue;

    // Normal en yüksek skorlu
    for (size_t i : idx) {
      if (isExplore.count(i)) continue;  // keşif öğeleri kendi yuvasından gelir
      if (tryTake(i, opt.maxPerAuthor, true)) {
        placed = true;
        break;
      }
    }

    // Çeşitlilik kısıtı akışı tıkadıysa KADEMELİ gevşet. Boş akış göstermektense
    // biraz tekrar iyidir; ama sınır tamamen kalkmaz — aynı yazar akışı ele geçiremez.
    if (!placed) {
      for (size_t i : idx) {
        if (tryTake(i, opt.maxPerAuthor, false)) {  // konu kısıtı kalkar
          placed = true;
          break;
        }
      }
    }
    if (!placed) {
      for (size_t i : idx) {
        if (tryTake(i, opt.maxPerAuthor * 2, false)) {  // yazar sınırı iki katına
          placed = true;
          break;
        }
      }
    }
    if (!placed) break;  // havuz gerçekten tükendi: limitten kısa dönmek doğrudur
  }

  return out;
}

}  // namespace hg::algo
