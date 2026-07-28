// Hanagram — reklam alanı implementasyonu
#include "ad.hpp"

namespace hg::domain {

const char* adStatusToString(AdStatus s) {
  switch (s) {
    case AdStatus::kDraft:    return "draft";
    case AdStatus::kActive:   return "active";
    case AdStatus::kPaused:   return "paused";
    case AdStatus::kExpired:  return "expired";
  }
  return "draft";
}

AdStatus adStatusFromString(const std::string& s) {
  if (s == "active")  return AdStatus::kActive;
  if (s == "paused")  return AdStatus::kPaused;
  if (s == "expired") return AdStatus::kExpired;
  return AdStatus::kDraft;
}

json::Value Ad::toJson() const {
  json::Value j = json::Value::obj();
  j.set("id", id);
  j.set("businessId", businessId);
  j.set("title", title);
  j.set("description", description);
  j.set("imageUrl", imageUrl);
  j.set("dailyBudgetKurus", dailyBudgetKurus);
  j.set("bid", bid);
  j.set("status", adStatusToString(status));
  j.set("impressions", impressions);
  j.set("clicks", clicks);
  j.set("createdAt", createdAt);
  j.set("updatedAt", updatedAt);
  json::Value topics = json::Value::arr();
  for (const auto& t : targetTopics) topics.push(t);
  j.set("targetTopics", topics);
  return j;
}

Ad Ad::fromJson(const json::Value& v) {
  Ad a;
  a.id = v["id"].asString();
  a.businessId = v["businessId"].asString();
  a.title = v["title"].asString();
  a.description = v["description"].asString();
  a.imageUrl = v["imageUrl"].asString();
  a.dailyBudgetKurus = v["dailyBudgetKurus"].asInt();
  a.bid = v["bid"].asNumber();
  a.status = adStatusFromString(v["status"].asString());
  a.impressions = v["impressions"].asInt();
  a.clicks = v["clicks"].asInt();
  a.createdAt = v["createdAt"].asInt();
  a.updatedAt = v["updatedAt"].asInt();
  const auto& topicsArr = v["targetTopics"].asArray();
  a.targetTopics.reserve(topicsArr.size());
  for (size_t i = 0; i < topicsArr.size(); ++i) {
    a.targetTopics.push_back(topicsArr[i].asString());
  }
  return a;
}

std::string sanitizeAdTitle(const std::string& raw) {
  size_t start = 0;
  while (start < raw.size() && static_cast<unsigned char>(raw[start]) <= 0x20) ++start;
  size_t end = raw.size();
  while (end > start && static_cast<unsigned char>(raw[end - 1]) <= 0x20) --end;
  std::string trimmed = raw.substr(start, end - start);

  if (trimmed.empty()) return {};

  size_t byteLen = 0;
  size_t charCount = 0;
  while (byteLen < trimmed.size() && charCount < kMaxAdTitleLength) {
    unsigned char c = static_cast<unsigned char>(trimmed[byteLen]);
    size_t charBytes = 1;
    if ((c & 0x80) != 0) {
      if ((c & 0xE0) == 0xC0) charBytes = 2;
      else if ((c & 0xF0) == 0xE0) charBytes = 3;
      else if ((c & 0xF8) == 0xF0) charBytes = 4;
    }
    if (byteLen + charBytes > trimmed.size()) break;
    byteLen += charBytes;
    ++charCount;
  }
  while (byteLen > 0 && (static_cast<unsigned char>(trimmed[byteLen]) & 0xC0) == 0x80) --byteLen;
  return trimmed.substr(0, byteLen);
}

std::string sanitizeAdDescription(const std::string& raw) {
  size_t start = 0;
  while (start < raw.size() && static_cast<unsigned char>(raw[start]) <= 0x20) ++start;
  size_t end = raw.size();
  while (end > start && static_cast<unsigned char>(raw[end - 1]) <= 0x20) --end;
  std::string trimmed = raw.substr(start, end - start);

  size_t byteLen = 0;
  size_t charCount = 0;
  while (byteLen < trimmed.size() && charCount < kMaxAdDescriptionLength) {
    unsigned char c = static_cast<unsigned char>(trimmed[byteLen]);
    size_t charBytes = 1;
    if ((c & 0x80) != 0) {
      if ((c & 0xE0) == 0xC0) charBytes = 2;
      else if ((c & 0xF0) == 0xE0) charBytes = 3;
      else if ((c & 0xF8) == 0xF0) charBytes = 4;
    }
    if (byteLen + charBytes > trimmed.size()) break;
    byteLen += charBytes;
    ++charCount;
  }
  while (byteLen > 0 && (static_cast<unsigned char>(trimmed[byteLen]) & 0xC0) == 0x80) --byteLen;
  return trimmed.substr(0, byteLen);
}

}  // namespace hg::domain