#include "learner.hpp"

#include <algorithm>
#include <cmath>

namespace hg::algo {

json::Value Calibration::toJson() const {
  json::Value v = json::Value::obj();
  v.set("applied", applied);
  v.set("reason", reason);
  v.set("before", before.toJson());
  v.set("after", after.toJson());
  v.set("brierBefore", brierBefore);
  v.set("brierAfter", brierAfter);
  v.set("engagementRate", engagementRate);
  v.set("sampleSize", sampleSize);
  v.set("at", at);
  return v;
}

void Learner::recordImpression(const Impression& imp) {
  impressions_.push_back(imp);
  while (impressions_.size() > window_) {
    if (impressions_.front().resolved && resolvedCount_ > 0) resolvedCount_--;
    impressions_.pop_front();
  }
}

void Learner::recordOutcome(const std::string& userId, const std::string& itemId,
                            bool engaged, int64_t dwellMs) {
  // Sondan başa: aynı öğe tekrar gösterilmişse en yenisi eşleşsin.
  for (auto it = impressions_.rbegin(); it != impressions_.rend(); ++it) {
    if (it->userId != userId || it->itemId != itemId) continue;
    if (it->resolved) continue;
    it->engaged = engaged;
    it->dwellMs = dwellMs;
    it->resolved = true;
    resolvedCount_++;
    return;
  }
}

bool Learner::ready() const { return resolvedCount_ >= kMinSamples; }

double Learner::recompute(const Weights& w, const ScoreParts& p) const {
  const double v = w.interest * p.interest + w.freshness * p.freshness +
                   w.quality * p.quality + w.affinity * p.affinity +
                   w.following * p.following;
  return std::clamp(v, 0.0, 1.0);
}

// Brier skoru: ortalama (tahmin − gerçek)². 0 mükemmel, 0.25 rastgele tahmin.
double Learner::brier(const Weights& w) const {
  double sum = 0.0;
  size_t n = 0;
  for (const auto& imp : impressions_) {
    if (!imp.resolved) continue;
    const double pred = recompute(w, imp.parts);
    const double actual = imp.engaged ? 1.0 : 0.0;
    sum += (pred - actual) * (pred - actual);
    n++;
  }
  return n == 0 ? 1.0 : sum / static_cast<double>(n);
}

double Learner::engagementRate() const {
  size_t engaged = 0, n = 0;
  for (const auto& imp : impressions_) {
    if (!imp.resolved) continue;
    n++;
    if (imp.engaged) engaged++;
  }
  return n == 0 ? 0.0 : static_cast<double>(engaged) / static_cast<double>(n);
}

double Learner::explorationYield() const {
  size_t engaged = 0, n = 0;
  for (const auto& imp : impressions_) {
    if (!imp.resolved || !imp.exploration) continue;
    n++;
    if (imp.engaged) engaged++;
  }
  return n == 0 ? 0.0 : static_cast<double>(engaged) / static_cast<double>(n);
}

namespace {

// Bir bileşenin öngörü gücü: yüksek değerli grup ile düşük değerli grubun
// etkileşim oranı farkı ("lift"). Pozitifse o bileşen gerçekten işe yarıyor.
double liftOf(const std::deque<Impression>& imps,
              double ScoreParts::*field) {
  std::vector<std::pair<double, bool>> rows;
  rows.reserve(imps.size());
  for (const auto& imp : imps) {
    if (!imp.resolved) continue;
    rows.emplace_back(imp.parts.*field, imp.engaged);
  }
  if (rows.size() < 20) return 0.0;

  std::sort(rows.begin(), rows.end(),
            [](const auto& a, const auto& b) { return a.first > b.first; });

  const size_t k = std::max<size_t>(rows.size() / 3, 5);
  size_t topEngaged = 0, bottomEngaged = 0;
  for (size_t i = 0; i < k; i++) {
    if (rows[i].second) topEngaged++;
    if (rows[rows.size() - 1 - i].second) bottomEngaged++;
  }
  const double top = static_cast<double>(topEngaged) / static_cast<double>(k);
  const double bottom = static_cast<double>(bottomEngaged) / static_cast<double>(k);
  return top - bottom;  // -1..1
}

}  // namespace

Calibration Learner::calibrate(const Weights& current, int64_t now) {
  Calibration cal;
  cal.at = now;
  cal.before = current;
  cal.after = current;
  cal.sampleSize = static_cast<int64_t>(resolvedCount_);
  cal.engagementRate = engagementRate();
  cal.brierBefore = brier(current);
  cal.brierAfter = cal.brierBefore;

  if (!ready()) {
    cal.reason = "yetersiz_veri";
    return cal;
  }

  // Her bileşenin gerçek öngörü gücünü ölç.
  const double lInterest = liftOf(impressions_, &ScoreParts::interest);
  const double lFreshness = liftOf(impressions_, &ScoreParts::freshness);
  const double lQuality = liftOf(impressions_, &ScoreParts::quality);
  const double lAffinity = liftOf(impressions_, &ScoreParts::affinity);
  const double lFollowing = liftOf(impressions_, &ScoreParts::following);

  const double meanLift = (lInterest + lFreshness + lQuality + lAffinity + lFollowing) / 5.0;

  // Ortalamadan iyi öngören bileşenin ağırlığı artar, kötü öngörenin azalır.
  // Adım küçük tutulur: sistem sarsılmadan, kademeli öğrenir.
  Weights next = current;
  auto step = [&](double& w, double lift) {
    const double delta = std::clamp((lift - meanLift) * 0.5, -kMaxStep, kMaxStep);
    w += delta;
  };
  step(next.interest, lInterest);
  step(next.freshness, lFreshness);
  step(next.quality, lQuality);
  step(next.affinity, lAffinity);
  step(next.following, lFollowing);
  next.clampAndNormalize();

  const double brierNext = brier(next);
  cal.after = next;
  cal.brierAfter = brierNext;

  // ——— KORUMA BANDI ———
  // Yeni ağırlıklar geçmiş veride daha kötü tahmin ediyorsa uygulanmaz.
  // Sistem kendini geliştirir; kendini bozamaz.
  const double improvement = cal.brierBefore - brierNext;
  if (improvement <= 0.0005) {
    cal.applied = false;
    cal.after = current;
    cal.brierAfter = cal.brierBefore;
    cal.reason = improvement < 0 ? "geri_alindi_kotulesme" : "degisim_anlamsiz";
    return cal;
  }

  cal.applied = true;
  cal.reason = "iyilesme";
  return cal;
}

json::Value Learner::stats() const {
  json::Value v = json::Value::obj();
  v.set("sampleSize", static_cast<int64_t>(resolvedCount_));
  v.set("pending", static_cast<int64_t>(impressions_.size() - resolvedCount_));
  v.set("engagementRate", engagementRate());
  v.set("explorationYield", explorationYield());
  v.set("ready", ready());
  return v;
}

json::Value Learner::toJson() const {
  json::Value arr = json::Value::arr();
  for (const auto& imp : impressions_) {
    json::Value p = json::Value::obj();
    p.set("i", imp.parts.interest);
    p.set("f", imp.parts.freshness);
    p.set("q", imp.parts.quality);
    p.set("a", imp.parts.affinity);
    p.set("fo", imp.parts.following);

    json::Value o = json::Value::obj();
    o.set("u", imp.userId);
    o.set("it", imp.itemId);
    o.set("p", p);
    o.set("pred", imp.predicted);
    o.set("ex", imp.exploration);
    o.set("at", imp.shownAt);
    o.set("en", imp.engaged);
    o.set("dw", imp.dwellMs);
    o.set("rs", imp.resolved);
    arr.push(o);
  }
  json::Value v = json::Value::obj();
  v.set("impressions", arr);
  v.set("window", static_cast<int64_t>(window_));
  return v;
}

void Learner::loadJson(const json::Value& v) {
  impressions_.clear();
  resolvedCount_ = 0;
  if (v.has("window")) window_ = static_cast<size_t>(v["window"].asInt(2000));
  for (const auto& o : v["impressions"].asArray()) {
    Impression imp;
    imp.userId = o["u"].asString();
    imp.itemId = o["it"].asString();
    imp.parts.interest = o["p"]["i"].asNumber();
    imp.parts.freshness = o["p"]["f"].asNumber();
    imp.parts.quality = o["p"]["q"].asNumber();
    imp.parts.affinity = o["p"]["a"].asNumber();
    imp.parts.following = o["p"]["fo"].asNumber();
    imp.predicted = o["pred"].asNumber();
    imp.exploration = o["ex"].asBool();
    imp.shownAt = o["at"].asInt();
    imp.engaged = o["en"].asBool();
    imp.dwellMs = o["dw"].asInt();
    imp.resolved = o["rs"].asBool();
    if (imp.resolved) resolvedCount_++;
    impressions_.push_back(imp);
  }
}

}  // namespace hg::algo
