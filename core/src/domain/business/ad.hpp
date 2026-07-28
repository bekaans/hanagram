// Hanagram — reklam alanı (SÖZLEŞME)
//
// İşletmenin keşfet/akışta gösterilen reklam kampanyaları. Her reklam bir
// işletmeye aittir ve belirli ilgi alanlarına hedeflenebilir.
//
// Tasarım kararları:
//  - Para birimi kuruştur (günlük bütçe). Kayan nokta kullanılmaz.
//  - `active` alanı reklamı devre dışı bırakır ama kaydı silmez.
//  - Algoritma (ranker) bu modülü bilmez; reklamları sosyal akışta
//    sponsored bayrağı ile karıştırır. Motor hazır, arayüz eksikti.
//  - Bu modül müşteri, randevu, satış alanlarını BİLMEZ.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "../../util/json.hpp"

namespace hg::domain {

enum class AdStatus : uint8_t {
  kDraft = 0,
  kActive = 1,
  kPaused = 2,
  kExpired = 3,
};

const char* adStatusToString(AdStatus s);
AdStatus adStatusFromString(const std::string& s);

struct Ad {
  std::string id;
  std::string businessId;
  std::string title;
  std::string description;
  std::string imageUrl;
  std::vector<std::string> targetTopics;
  int64_t dailyBudgetKurus = 0;
  double bid = 0.0;
  AdStatus status = AdStatus::kDraft;
  int64_t impressions = 0;
  int64_t clicks = 0;
  int64_t createdAt = 0;
  int64_t updatedAt = 0;

  json::Value toJson() const;
  static Ad fromJson(const json::Value& v);
};

/// Reklam başlığını doğrular ve kırpılmış hâlini verir.
std::string sanitizeAdTitle(const std::string& raw);

/// Reklam açıklamasını doğrular ve kırpılmış hâlini verir.
std::string sanitizeAdDescription(const std::string& raw);

constexpr size_t kMaxAdTitleLength = 80;
constexpr size_t kMaxAdDescriptionLength = 500;

}  // namespace hg::domain