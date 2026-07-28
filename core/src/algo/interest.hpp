// Hanagram — ilgi profili
//
// Her kullanıcının konu → ağırlık vektörü. Her etkileşimde güncellenir; kullanıcı
// kullandıkça kişiselleşir. Bu, "kendi kendini geliştiren" sistemin BİRİNCİ seviyesi
// (docs/03-algoritma.md).
//
// Tasarım kararları:
//  - Seyrek (sparse) vektör: kullanıcı yalnızca ilgilendiği konuları taşır.
//  - Zaman bozunumu: eski ilgi kendiliğinden zayıflar, kullanıcı değişebilir.
//  - Negatif sinyal birinci sınıf: "ilgilenmiyorum" gerçekten etkiler.
#pragma once

#include <string>
#include <unordered_map>
#include <vector>

#include "../kernel/clock.hpp"
#include "../util/json.hpp"

namespace hg::algo {

// Kullanıcının içerikle kurduğu ilişki türleri. Değerleri signalWeight() belirler.
enum class SignalKind {
  View,        // akışta göründü
  Dwell,       // üzerinde kaldı (süre ayrıca taşınır)
  Like,
  Comment,
  Save,
  Share,
  Follow,
  ProfileVisit,
  ProductTap,  // pazaryeri: ürüne dokundu
  Skip,        // hızlıca geçti — zayıf negatif
  Hide,        // "ilgilenmiyorum" — güçlü negatif
  Report,
};

struct Signal {
  std::string userId;
  std::string itemId;
  std::string authorId;
  std::vector<std::string> topics;
  SignalKind kind = SignalKind::View;
  int64_t dwellMs = 0;  // yalnızca Dwell için anlamlı
  int64_t at = 0;
};

// Sinyalin ham etkisi. Negatif değerler ilgiyi azaltır.
double signalWeight(SignalKind kind);
const char* signalName(SignalKind kind);
bool signalFromName(const std::string& name, SignalKind& out);

// Seyrek ilgi vektörü.
class InterestProfile {
 public:
  // Konu ağırlıkları (normalize edilmiş, toplam ≈ 1).
  const std::unordered_map<std::string, double>& topics() const { return topics_; }

  // Yazar yakınlığı: bu kullanıcı o yazarla ne kadar ilgilenmiş.
  const std::unordered_map<std::string, double>& authors() const { return authors_; }

  double topicWeight(const std::string& topic) const;
  double authorAffinity(const std::string& authorId) const;

  // Bir sinyali profile işle. `now` zaman bozunumu için gerekli.
  void apply(const Signal& s, int64_t now);

  // Kosinüs benzerliği: içeriğin konuları bu profile ne kadar uyuyor (0..1).
  double match(const std::vector<std::string>& itemTopics) const;

  // Profil ne kadar oturmuş: 0 = yeni kullanıcı (soğuk başlangıç), 1 = net ilgi.
  // Keşif oranını belirlemekte kullanılır.
  double confidence() const;

  int64_t lastUpdate() const { return lastUpdate_; }
  int64_t signalCount() const { return signalCount_; }

  json::Value toJson() const;
  static InterestProfile fromJson(const json::Value& v);

 private:
  void decay(int64_t now);
  void normalize();

  std::unordered_map<std::string, double> topics_;
  std::unordered_map<std::string, double> authors_;
  int64_t lastUpdate_ = 0;
  int64_t signalCount_ = 0;
};

// Bozunum yarı ömrü: 21 gün. Kullanıcının bir aylık ilgisi yarıya iner —
// hem değişime açık hem de gürültüye dayanıklı.
constexpr int64_t kInterestHalfLifeMs = 21LL * 24 * 3600 * 1000;

}  // namespace hg::algo
