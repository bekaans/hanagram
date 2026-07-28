#include "interest.hpp"

#include <algorithm>
#include <cmath>

namespace hg::algo {

double signalWeight(SignalKind kind) {
  switch (kind) {
    case SignalKind::View:         return 0.08;
    case SignalKind::Dwell:        return 0.60;  // süreye göre ölçeklenir
    case SignalKind::Like:         return 1.00;
    case SignalKind::Comment:      return 1.60;
    case SignalKind::Save:         return 2.00;
    case SignalKind::Share:        return 2.40;
    case SignalKind::Follow:       return 3.00;
    case SignalKind::ProfileVisit: return 0.80;
    case SignalKind::ProductTap:   return 2.00;
    case SignalKind::Skip:        return -0.40;
    case SignalKind::Hide:        return -3.00;
    case SignalKind::Report:      return -5.00;
  }
  return 0.0;
}

const char* signalName(SignalKind kind) {
  switch (kind) {
    case SignalKind::View:         return "view";
    case SignalKind::Dwell:        return "dwell";
    case SignalKind::Like:         return "like";
    case SignalKind::Comment:      return "comment";
    case SignalKind::Save:         return "save";
    case SignalKind::Share:        return "share";
    case SignalKind::Follow:       return "follow";
    case SignalKind::ProfileVisit: return "profile_visit";
    case SignalKind::ProductTap:   return "product_tap";
    case SignalKind::Skip:         return "skip";
    case SignalKind::Hide:         return "hide";
    case SignalKind::Report:       return "report";
  }
  return "view";
}

bool signalFromName(const std::string& name, SignalKind& out) {
  static const std::pair<const char*, SignalKind> kMap[] = {
      {"view", SignalKind::View},
      {"dwell", SignalKind::Dwell},
      {"like", SignalKind::Like},
      {"comment", SignalKind::Comment},
      {"save", SignalKind::Save},
      {"share", SignalKind::Share},
      {"follow", SignalKind::Follow},
      {"profile_visit", SignalKind::ProfileVisit},
      {"product_tap", SignalKind::ProductTap},
      {"skip", SignalKind::Skip},
      {"hide", SignalKind::Hide},
      {"report", SignalKind::Report},
  };
  for (const auto& [n, k] : kMap) {
    if (name == n) {
      out = k;
      return true;
    }
  }
  return false;
}

double InterestProfile::topicWeight(const std::string& topic) const {
  auto it = topics_.find(topic);
  return it == topics_.end() ? 0.0 : it->second;
}

double InterestProfile::authorAffinity(const std::string& authorId) const {
  auto it = authors_.find(authorId);
  return it == authors_.end() ? 0.0 : it->second;
}

void InterestProfile::decay(int64_t now) {
  if (lastUpdate_ == 0 || now <= lastUpdate_) {
    lastUpdate_ = now;
    return;
  }
  const double elapsed = static_cast<double>(now - lastUpdate_);
  const double factor = std::pow(0.5, elapsed / static_cast<double>(kInterestHalfLifeMs));
  if (factor >= 0.999999) {
    lastUpdate_ = now;
    return;
  }
  for (auto& [_, w] : topics_) w *= factor;
  for (auto& [_, w] : authors_) w *= factor;
  lastUpdate_ = now;
}

void InterestProfile::apply(const Signal& s, int64_t now) {
  decay(now);

  double w = signalWeight(s.kind);

  // Süre sinyali: 2 sn altı sayılmaz, 30 sn'de doyuma ulaşır.
  if (s.kind == SignalKind::Dwell) {
    if (s.dwellMs < 2000) return;
    const double capped = std::min(static_cast<double>(s.dwellMs), 30000.0);
    w *= (capped - 2000.0) / 28000.0;
    if (w <= 0.0) return;
  }

  // Konu ağırlığı: bir içerik birden çok konuya aitse etki paylaştırılır —
  // aksi halde çok etiketli içerikler haksız avantaj kazanır.
  if (!s.topics.empty()) {
    const double share = w / static_cast<double>(s.topics.size());
    for (const auto& t : s.topics) {
      double& cur = topics_[t];
      cur += share;
      // Negatife düşen konular sıfırlanır; ilgisizlik "borç" biriktirmez.
      if (cur < 0.0) cur = 0.0;
    }
  }

  if (!s.authorId.empty()) {
    double& a = authors_[s.authorId];
    a += w * 0.5;  // yazar yakınlığı konudan daha yavaş birikir
    if (a < 0.0) a = 0.0;
  }

  signalCount_++;
  normalize();
}

void InterestProfile::normalize() {
  // Sıfıra düşenleri temizle — vektör seyrek kalsın.
  for (auto it = topics_.begin(); it != topics_.end();) {
    it = (it->second < 1e-6) ? topics_.erase(it) : std::next(it);
  }
  for (auto it = authors_.begin(); it != authors_.end();) {
    it = (it->second < 1e-6) ? authors_.erase(it) : std::next(it);
  }

  double sum = 0.0;
  for (const auto& [_, w] : topics_) sum += w;
  if (sum > 0.0) {
    for (auto& [_, w] : topics_) w /= sum;
  }

  // Yazar yakınlığı 0..1 aralığına sıkıştırılır (normalize edilmez —
  // "kaç yazarla ilgileniyorum" bilgisi korunmalı).
  double maxA = 0.0;
  for (const auto& [_, w] : authors_) maxA = std::max(maxA, w);
  if (maxA > 1.0) {
    for (auto& [_, w] : authors_) w /= maxA;
  }
}

double InterestProfile::match(const std::vector<std::string>& itemTopics) const {
  if (itemTopics.empty() || topics_.empty()) return 0.0;

  // İçerik vektörü: eşit ağırlıklı, birim uzunlukta.
  const double itemW = 1.0 / std::sqrt(static_cast<double>(itemTopics.size()));

  double dot = 0.0;
  double profileNorm = 0.0;
  for (const auto& [_, w] : topics_) profileNorm += w * w;
  profileNorm = std::sqrt(profileNorm);
  if (profileNorm <= 0.0) return 0.0;

  for (const auto& t : itemTopics) {
    auto it = topics_.find(t);
    if (it != topics_.end()) dot += it->second * itemW;
  }
  const double sim = dot / profileNorm;
  return std::clamp(sim, 0.0, 1.0);
}

double InterestProfile::confidence() const {
  // İki bileşen: yeterince sinyal var mı, ve ilgi belirgin mi (dağınık değil).
  const double volume = 1.0 - std::exp(-static_cast<double>(signalCount_) / 25.0);
  if (topics_.empty()) return 0.0;

  // Konsantrasyon: en yüksek 3 konunun toplam payı.
  std::vector<double> ws;
  ws.reserve(topics_.size());
  for (const auto& [_, w] : topics_) ws.push_back(w);
  std::sort(ws.begin(), ws.end(), std::greater<double>());
  double top = 0.0;
  for (size_t i = 0; i < ws.size() && i < 3; i++) top += ws[i];

  return std::clamp(volume * 0.6 + top * 0.4, 0.0, 1.0);
}

json::Value InterestProfile::toJson() const {
  json::Value t = json::Value::obj();
  for (const auto& [k, w] : topics_) t.set(k, w);
  json::Value a = json::Value::obj();
  for (const auto& [k, w] : authors_) a.set(k, w);

  json::Value v = json::Value::obj();
  v.set("topics", t);
  v.set("authors", a);
  v.set("lastUpdate", lastUpdate_);
  v.set("signalCount", signalCount_);
  return v;
}

InterestProfile InterestProfile::fromJson(const json::Value& v) {
  InterestProfile p;
  for (const auto& [k, w] : v["topics"].asObject()) p.topics_[k] = w.asNumber();
  for (const auto& [k, w] : v["authors"].asObject()) p.authors_[k] = w.asNumber();
  p.lastUpdate_ = v["lastUpdate"].asInt();
  p.signalCount_ = v["signalCount"].asInt();
  return p;
}

}  // namespace hg::algo
