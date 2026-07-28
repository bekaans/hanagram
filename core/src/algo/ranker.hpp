// Hanagram — sıralama motoru
//
// Aday havuzunu kullanıcıya göre sıralar. Üç iş bir arada yapılır:
//   1. Skorlama    — içerik bu kullanıcıya ne kadar uygun
//   2. Çeşitlilik  — aynı yazar/konu peş peşe gelmesin
//   3. Keşif       — akışın bir kısmı kasıtlı olarak belirsiz içeriğe ayrılır
//
// Her skor AÇIKLANABİLİR: hangi bileşenin ne kadar katkı verdiği taşınır.
// Admin panelinde "bu neden gösterildi" sorusu bu veriden cevaplanır.
#pragma once

#include <string>
#include <vector>

#include "interest.hpp"

namespace hg::algo {

struct Candidate {
  std::string id;
  std::string authorId;
  std::vector<std::string> topics;
  int64_t createdAt = 0;

  // Toplu etkileşim sayaçları (kalite sinyali)
  int64_t views = 0;
  int64_t likes = 0;
  int64_t comments = 0;
  int64_t shares = 0;

  bool following = false;   // kullanıcı yazarı takip ediyor
  bool seen = false;        // daha önce gösterildi
  bool sponsored = false;   // reklam
  double bid = 0.0;         // reklam teklifi (yalnızca sponsored)
};

// Skorun bileşenleri — açıklanabilirlik için taşınır.
struct ScoreParts {
  double interest = 0;
  double freshness = 0;
  double quality = 0;
  double affinity = 0;
  double following = 0;
  double penalty = 0;
  double diversity = 0;
};

struct ScoredItem {
  std::string id;
  double score = 0;
  double predicted = 0;   // tahmini etkileşim olasılığı (0..1) — öğrenme bunu ölçer
  bool exploration = false;
  bool sponsored = false;
  ScoreParts parts;
};

// Skorlama ağırlıkları. Öğrenme katmanı bunları zamanla kalibre eder (learner.hpp).
struct Weights {
  double interest = 0.34;
  double freshness = 0.18;
  double quality = 0.14;
  double affinity = 0.18;
  double following = 0.16;

  json::Value toJson() const;
  static Weights fromJson(const json::Value& v);
  void clampAndNormalize();
};

struct RankOptions {
  int limit = 20;
  // Keşif tabanı; kullanıcı profili belirsizse otomatik yükselir.
  double exploreBase = 0.15;
  // Aynı yazardan en fazla kaç öğe (çeşitlilik).
  int maxPerAuthor = 2;
  // Kaç öğede bir reklam yuvası. 0 = reklam yok.
  int adEvery = 6;
  // Görülmüş içeriğe uygulanan çarpan.
  double seenPenalty = 0.25;
  bool followingOnly = false;  // "Takip" sekmesi
};

class Ranker {
 public:
  Ranker() = default;
  explicit Ranker(Weights w) : w_(w) {}

  void setWeights(const Weights& w) { w_ = w; }
  const Weights& weights() const { return w_; }

  std::vector<ScoredItem> rank(const std::vector<Candidate>& pool,
                               const InterestProfile& profile,
                               int64_t now,
                               const RankOptions& opt) const;

  // Tek adayın ham skoru (test ve açıklama için).
  ScoredItem score(const Candidate& c, const InterestProfile& p, int64_t now,
                   const RankOptions& opt) const;

 private:
  Weights w_;
};

// Tazelik: yarı ömür 18 saat. Sosyal akışta içerik hızlı eskir.
constexpr int64_t kFreshnessHalfLifeMs = 18LL * 3600 * 1000;

// Ağırlık sınırları — öğrenme bunların dışına çıkamaz (yapısal koruma).
constexpr double kMinWeight = 0.05;
constexpr double kMaxWeight = 0.60;

}  // namespace hg::algo
