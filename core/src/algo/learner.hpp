// Hanagram — öğrenme katmanı (kendi kendini geliştirme)
//
// Sistem üç seviyede öğrenir (docs/03-algoritma.md):
//   1. Kullanıcı — ilgi vektörü (interest.hpp)
//   2. SİSTEM    — skorlama ağırlıkları  ← BU DOSYA
//   3. Keşif     — belirsiz içeriği yoklama (ranker.hpp)
//
// Çalışma biçimi:
//   gösterim kaydet → sonucu ölç → hangi bileşen gerçekten öngörüyor → ağırlığı kaydır
//   → yeni ağırlığı geçmiş veride sına → kötüyse GERİ AL.
//
// Son adım pazarlıksız: kendini geliştiren bir sistemin kendini bozma hakkı yoktur.
#pragma once

#include <deque>
#include <string>
#include <vector>

#include "ranker.hpp"

namespace hg::algo {

// Bir gösterim ve sonucu.
struct Impression {
  std::string userId;
  std::string itemId;
  ScoreParts parts;     // gösterim anındaki bileşen değerleri
  double predicted = 0; // o anki tahmin
  bool exploration = false;
  int64_t shownAt = 0;

  // Sonuç — gösterimden sonra doldurulur.
  bool engaged = false;  // beğeni/yorum/kaydetme/paylaşma/anlamlı süre
  int64_t dwellMs = 0;
  bool resolved = false; // sonuç geldi mi (yoksa henüz bekliyor)
};

// Kalibrasyon sonucu — admin panelinde gösterilir.
struct Calibration {
  bool applied = false;
  std::string reason;
  Weights before;
  Weights after;
  double brierBefore = 0;
  double brierAfter = 0;
  double engagementRate = 0;
  int64_t sampleSize = 0;
  int64_t at = 0;

  json::Value toJson() const;
};

class Learner {
 public:
  explicit Learner(size_t windowSize = 2000) : window_(windowSize) {}

  // Gösterimi kaydet (sonuç henüz yok).
  void recordImpression(const Impression& imp);

  // Sonucu bildir. Eşleşen gösterim bulunamazsa yok sayılır.
  void recordOutcome(const std::string& userId, const std::string& itemId,
                     bool engaged, int64_t dwellMs);

  // Yeterli veri birikti mi (kalibrasyon için).
  bool ready() const;

  // Ağırlıkları kalibre et. Geri alma dahil, tüm karar burada verilir.
  Calibration calibrate(const Weights& current, int64_t now);

  // Ölçümler
  double brier(const Weights& w) const;      // tahmin kalibrasyon hatası (düşük iyi)
  double engagementRate() const;
  double explorationYield() const;           // keşif öğelerinin etkileşim oranı
  size_t sampleSize() const { return resolvedCount_; }

  const std::deque<Impression>& impressions() const { return impressions_; }
  json::Value stats() const;

  // Kalıcılık
  json::Value toJson() const;
  void loadJson(const json::Value& v);

 private:
  double recompute(const Weights& w, const ScoreParts& p) const;

  std::deque<Impression> impressions_;
  size_t window_;
  size_t resolvedCount_ = 0;
};

// Kalibrasyon için gereken en az çözülmüş gösterim sayısı.
constexpr size_t kMinSamples = 120;
// Ağırlık başına en fazla kayma — sistem sarsılmadan öğrenir.
constexpr double kMaxStep = 0.04;

}  // namespace hg::algo
