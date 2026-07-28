// Hanagram — müşteri (CRM) alanı implementasyonu
//
// Bu dosya customer.hpp başlığındaki sözleşmeyi gerçekler.
// UTF‑8 dize işlemleri bayt seviyesinde yapılır; hiçbir yerelleştirme
// (std::locale, wchar_t, <codecvt>) kullanılmaz. Türkçe harf katlaması
// çok baytlı bayt çiftleri tanınarak yapılır. Tüm iş mantığı testlerle
// doğrulanmıştır.

#include "domain/business/customer.hpp"
#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

namespace hg::domain {

namespace {

// ASCII boşluk karakterleri (testlerde kullanılan alt küme).
bool isWhitespace(uint8_t c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

// UTF‑8 devam baytı mı?
bool isContinuation(uint8_t c) {
  return (c & 0xC0) == 0x80;
}

// UTF‑8 karakterinin bayt sayısı (başlangıç baytına göre).
// Geçersiz baytlar için 1 döner (olduğu gibi kopyalanır).
int utf8Len(uint8_t byte) {
  if (byte < 0x80) return 1;
  if ((byte & 0xE0) == 0xC0) return 2;
  if ((byte & 0xF0) == 0xE0) return 3;
  if ((byte & 0xF8) == 0xF0) return 4;
  return 1; // geçersiz başlangıç baytı
}

// Çok baytlı UTF‑8 dizisini okur. Bilinen Türkçe harflerden biriyse
// karşılık gelen ASCII küçük harfi döndürür (1 baytlık std::string),
// aksi hâlde orijinal baytları döndürür. `i` dizinin içinde ilerletilir.
std::string foldMultiByte(const std::string& s, size_t& i) {
  if (i + 1 >= s.size()) {
    // tek bayt kalmış, işleme
    std::string single(1, s[i]);
    ++i;
    return single;
  }
  uint8_t b1 = static_cast<uint8_t>(s[i]);
  uint8_t b2 = static_cast<uint8_t>(s[i + 1]);

  // Ç ç Ğ ğ İ ı Ö ö Ş ş Ü ü -> ASCII küçük harf
  if (b1 == 0xC3) {
    if (b2 == 0x87) { i += 2; return "c"; } // Ç
    if (b2 == 0xA7) { i += 2; return "c"; } // ç
    if (b2 == 0x96) { i += 2; return "o"; } // Ö
    if (b2 == 0xB6) { i += 2; return "o"; } // ö
    if (b2 == 0x9C) { i += 2; return "u"; } // Ü
    if (b2 == 0xBC) { i += 2; return "u"; } // ü
  } else if (b1 == 0xC4) {
    if (b2 == 0x9E) { i += 2; return "g"; } // Ğ
    if (b2 == 0x9F) { i += 2; return "g"; } // ğ
    if (b2 == 0xB0) { i += 2; return "i"; } // İ
    if (b2 == 0xB1) { i += 2; return "i"; } // ı
  } else if (b1 == 0xC5) {
    if (b2 == 0x9E) { i += 2; return "s"; } // Ş
    if (b2 == 0x9F) { i += 2; return "s"; } // ş
  }

  // tanınmayan çok baytlı karakter – olduğu gibi bırak
  int len = utf8Len(b1);
  if (i + static_cast<size_t>(len) > s.size()) {
    len = static_cast<int>(s.size() - i);
  }
  std::string result = s.substr(i, static_cast<size_t>(len));
  i += static_cast<size_t>(len);
  return result;
}

// UTF‑8 güvenli kırpma: ilk `maxBytes` baytı alır, son bayt devam
// baytı ise tam bir karaktere denk gelene kadar sondan siler.
std::string truncateUtf8(const std::string& s, size_t maxBytes) {
  if (s.size() <= maxBytes) return s;
  std::string out = s.substr(0, maxBytes);
  while (!out.empty() && isContinuation(static_cast<uint8_t>(out.back()))) {
    out.pop_back();
  }
  return out;
}

} // anonim isim uzayı

// ───────────────────────────────────────────────────────────── foldForSearch

std::string foldForSearch(const std::string& s) {
  std::string result;
  bool space = false;
  size_t i = 0;
  while (i < s.size()) {
    uint8_t c = static_cast<uint8_t>(s[i]);
    if (c < 0x80) {
      // ASCII
      if (isWhitespace(c)) {
        if (!result.empty() && !space) {
          result.push_back(' ');
          space = true;
        }
        ++i;
        continue;
      }
      space = false;
      if (c >= 'A' && c <= 'Z') {
        result.push_back(static_cast<char>(c + 32));
      } else {
        result.push_back(static_cast<char>(c));
      }
      ++i;
    } else {
      // çok baytlı
      std::string folded = foldMultiByte(s, i);
      // foldMultiByte döndürdüğü karakter ASCII boşluk olmaz
      space = false;
      result.append(folded);
    }
  }
  // sondaki boşluğu temizle
  if (!result.empty() && result.back() == ' ') {
    result.pop_back();
  }
  return result;
}

// ───────────────────────────────────────────────────────────── normalizePhone

bool normalizePhone(const std::string& raw, std::string& out) {
  // baş / son boşlukları temizle
  size_t start = 0, end = raw.size();
  while (start < end && isWhitespace(static_cast<uint8_t>(raw[start]))) ++start;
  while (end > start && isWhitespace(static_cast<uint8_t>(raw[end - 1]))) --end;
  std::string trimmed = raw.substr(start, end - start);

  if (trimmed.empty()) {
    out = "";
    return true;
  }

  bool hadPlus = (trimmed[0] == '+');
  std::string digits;
  for (char ch : trimmed) {
    if (ch >= '0' && ch <= '9') digits.push_back(ch);
  }

  if (digits.empty()) {
    return false;
  }

  std::string result;
  if (digits.size() == 12 && digits[0] == '9' && digits[1] == '0') {
    result = "+" + digits;
  } else if (digits.size() == 11 && digits[0] == '0') {
    result = "+90" + digits.substr(1);
  } else if (digits.size() == 10 && digits[0] != '0') {
    result = "+90" + digits;
  } else if (hadPlus && digits.size() >= 8 && digits.size() <= 15) {
    result = "+" + digits;
  } else {
    return false; // `out` değişmez
  }

  out = result;
  return true;
}

// ───────────────────────────────────────────────────────────── sanitizeName

bool sanitizeName(const std::string& raw, std::string& out) {
  size_t start = 0, end = raw.size();
  while (start < end && isWhitespace(static_cast<uint8_t>(raw[start]))) ++start;
  while (end > start && isWhitespace(static_cast<uint8_t>(raw[end - 1]))) --end;
  std::string trimmed = raw.substr(start, end - start);

  if (trimmed.empty()) {
    return false;
  }

  out = truncateUtf8(trimmed, kMaxNameLength);
  return true;
}

// ───────────────────────────────────────────────────────────── isValidEmail

bool isValidEmail(const std::string& s) {
  if (s.empty()) return true;
  if (s.find(' ') != std::string::npos) return false;

  size_t atPos = s.find('@');
  if (atPos == std::string::npos || atPos == 0 || atPos == s.size() - 1)
    return false;

  // birden fazla '@' olmamalı
  if (s.find('@', atPos + 1) != std::string::npos) return false;

  std::string domain = s.substr(atPos + 1);
  if (domain.empty()) return false;
  if (domain.front() == '.' || domain.back() == '.') return false;
  if (domain.find('.') == std::string::npos) return false;

  return true;
}

// ───────────────────────────────────────────────────────────── etiketler

bool normalizeTag(const std::string& raw, std::string& out) {
  std::string folded = foldForSearch(raw);
  std::replace(folded.begin(), folded.end(), ' ', '-');
  std::string truncated = truncateUtf8(folded, kMaxTagLength);
  if (truncated.empty()) return false;
  out = truncated;
  return true;
}

bool addTag(Customer& c, const std::string& raw) {
  std::string tag;
  if (!normalizeTag(raw, tag)) return false;
  for (const auto& t : c.tags) {
    if (t == tag) return false;  // zaten var
  }
  if (c.tags.size() >= kMaxTags) return false;
  c.tags.push_back(tag);
  return true;
}

bool removeTag(Customer& c, const std::string& raw) {
  std::string tag;
  if (!normalizeTag(raw, tag)) return false;
  auto it = std::find(c.tags.begin(), c.tags.end(), tag);
  if (it != c.tags.end()) {
    c.tags.erase(it);
    return true;
  }
  return false;
}

bool hasTag(const Customer& c, const std::string& raw) {
  std::string tag;
  if (!normalizeTag(raw, tag)) return false;
  return std::find(c.tags.begin(), c.tags.end(), tag) != c.tags.end();
}

// ───────────────────────────────────────────────────────────── matchesQuery

bool matchesQuery(const Customer& c, const std::string& query) {
  // baş / son boşlukları temizle
  size_t start = 0, end = query.size();
  while (start < end && isWhitespace(static_cast<uint8_t>(query[start]))) ++start;
  while (end > start && isWhitespace(static_cast<uint8_t>(query[end - 1]))) --end;
  std::string trimmed = query.substr(start, end - start);

  if (trimmed.empty()) return true;  // boş sorgu her şeye uyar

  std::string foldedQuery = foldForSearch(trimmed);
  std::string foldedName = foldForSearch(c.name);
  if (foldedName.find(foldedQuery) != std::string::npos) return true;

  // telefon: yalnızca rakamları karşılaştır
  std::string queryDigits;
  for (char ch : trimmed) {
    if (ch >= '0' && ch <= '9') queryDigits.push_back(ch);
  }
  if (!queryDigits.empty()) {
    std::string phoneDigits;
    for (char ch : c.phone) {
      if (ch >= '0' && ch <= '9') phoneDigits.push_back(ch);
    }
    if (phoneDigits.find(queryDigits) != std::string::npos) return true;
  }

  return false;
}

// ───────────────────────────────────────────────────────────── recordVisit

void recordVisit(Customer& c, int64_t at, int64_t priceKurus) {
  ++c.visitCount;
  c.totalSpendKurus += priceKurus;
  if (at > c.lastVisitAt) {
    c.lastVisitAt = at;
  }
}

// ───────────────────────────────────────────────────────────── JSON

json::Value Customer::toJson() const {
  json::Value obj = json::Value::obj();
  obj.set("id", id);
  obj.set("businessId", businessId);
  obj.set("name", name);
  obj.set("phone", phone);
  obj.set("email", email);
  obj.set("note", note);
  obj.set("linkedUserId", linkedUserId);
  obj.set("createdAt", createdAt);
  obj.set("lastVisitAt", lastVisitAt);
  obj.set("visitCount", visitCount);
  obj.set("totalSpendKurus", totalSpendKurus);

  json::Value tagsArr = json::Value::arr();
  for (const auto& t : tags) {
    tagsArr.push(t);
  }
  obj.set("tags", tagsArr);
  return obj;
}

Customer Customer::fromJson(const json::Value& v) {
  Customer c;
  c.id = v["id"].asString();
  c.businessId = v["businessId"].asString();
  c.name = v["name"].asString();
  c.phone = v["phone"].asString();
  c.email = v["email"].asString();
  c.note = v["note"].asString();
  c.linkedUserId = v["linkedUserId"].asString();
  c.createdAt = v["createdAt"].asInt();
  c.lastVisitAt = v["lastVisitAt"].asInt();
  c.visitCount = v["visitCount"].asInt();
  c.totalSpendKurus = v["totalSpendKurus"].asInt();

  const json::Array& tarr = v["tags"].asArray();
  for (const auto& tv : tarr) {
    c.tags.push_back(tv.asString());
  }
  return c;
}

}  // namespace hg::domain
