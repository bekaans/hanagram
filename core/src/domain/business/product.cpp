// Hanagram — ürün alanı implementasyonu
//
// customer.cpp ile aynı kalıbı izler: JSON dönüşümü, doğrulama,
// arama eşleme. Para kuruştur, kayan nokta yok.
#include "product.hpp"

#include "customer.hpp"  // foldForSearch

namespace hg::domain {

json::Value Product::toJson() const {
  json::Value j = json::Value::obj();
  j.set("id", id);
  j.set("businessId", businessId);
  j.set("name", name);
  j.set("description", description);
  j.set("priceKurus", priceKurus);
  j.set("category", category);
  j.set("active", active);
  j.set("createdAt", createdAt);
  j.set("updatedAt", updatedAt);
  return j;
}

Product Product::fromJson(const json::Value& v) {
  Product p;
  p.id = v["id"].asString();
  p.businessId = v["businessId"].asString();
  p.name = v["name"].asString();
  p.description = v["description"].asString();
  p.priceKurus = v["priceKurus"].asInt();
  p.category = v["category"].asString();
  p.active = v["active"].asBool();
  p.createdAt = v["createdAt"].asInt();
  p.updatedAt = v["updatedAt"].asInt();
  return p;
}

bool sanitizeProductName(const std::string& raw, std::string& out) {
  // Başta/sondaki boşlukları at
  size_t start = 0;
  while (start < raw.size() && static_cast<unsigned char>(raw[start]) <= 0x20) {
    ++start;
  }
  size_t end = raw.size();
  while (end > start && static_cast<unsigned char>(raw[end - 1]) <= 0x20) {
    --end;
  }
  std::string trimmed = raw.substr(start, end - start);

  // Boş ad geçersiz
  if (trimmed.empty()) return false;

  // UTF-8 güvenli kırpma: çok baytlı karakterin ortasını kesme
  size_t byteLen = 0;
  size_t charCount = 0;
  while (byteLen < trimmed.size() && charCount < kMaxProductNameLength) {
    unsigned char c = static_cast<unsigned char>(trimmed[byteLen]);
    size_t charBytes = 1;
    if ((c & 0x80) != 0) {
      if ((c & 0xE0) == 0xC0) charBytes = 2;
      else if ((c & 0xF0) == 0xE0) charBytes = 3;
      else if ((c & 0xF8) == 0xF0) charBytes = 4;
    }
    if (byteLen + charBytes > trimmed.size()) break;  // eksik bayt
    byteLen += charBytes;
    ++charCount;
  }
  // Kırpma noktası çok baytlı karakterin ortasındaysa geri al
  while (byteLen > 0 && (static_cast<unsigned char>(trimmed[byteLen]) & 0xC0) == 0x80) {
    --byteLen;
  }
  out = trimmed.substr(0, byteLen);
  return true;
}

bool sanitizeCategory(const std::string& raw, std::string& out) {
  std::string folded = foldForSearch(raw);
  if (folded.empty()) return false;

  // UTF-8 güvenli kırpma
  size_t byteLen = 0;
  size_t charCount = 0;
  while (byteLen < folded.size() && charCount < kMaxCategoryLength) {
    unsigned char c = static_cast<unsigned char>(folded[byteLen]);
    size_t charBytes = 1;
    if ((c & 0x80) != 0) {
      if ((c & 0xE0) == 0xC0) charBytes = 2;
      else if ((c & 0xF0) == 0xE0) charBytes = 3;
      else if ((c & 0xF8) == 0xF0) charBytes = 4;
    }
    if (byteLen + charBytes > folded.size()) break;
    byteLen += charBytes;
    ++charCount;
  }
  while (byteLen > 0 && (static_cast<unsigned char>(folded[byteLen]) & 0xC0) == 0x80) {
    --byteLen;
  }
  out = folded.substr(0, byteLen);
  return true;
}

std::string sanitizeDescription(const std::string& raw) {
  // Başta/sondaki boşlukları at
  size_t start = 0;
  while (start < raw.size() && static_cast<unsigned char>(raw[start]) <= 0x20) {
    ++start;
  }
  size_t end = raw.size();
  while (end > start && static_cast<unsigned char>(raw[end - 1]) <= 0x20) {
    --end;
  }
  std::string trimmed = raw.substr(start, end - start);

  // UTF-8 güvenli kırpma
  size_t byteLen = 0;
  size_t charCount = 0;
  while (byteLen < trimmed.size() && charCount < kMaxDescriptionLength) {
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
  while (byteLen > 0 && (static_cast<unsigned char>(trimmed[byteLen]) & 0xC0) == 0x80) {
    --byteLen;
  }
  return trimmed.substr(0, byteLen);
}

bool matchesProductQuery(const Product& p, const std::string& query) {
  std::string q = foldForSearch(query);
  if (q.empty()) return true;
  std::string nameFolded = foldForSearch(p.name);
  return nameFolded.find(q) != std::string::npos;
}

}  // namespace hg::domain
