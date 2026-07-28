#include "messaging.hpp"

#include <cctype>

namespace hg::domain {

namespace {

// Crockford Base32 — sohbet kimliği okunabilir ve dosya adı güvenli olsun diye.
constexpr char kAlphabet[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

// FNV-1a. Kriptografik değil; buradaki tek gereksinim aynı girdinin her platformda
// aynı çıktıyı vermesi — std::hash bunu garanti etmez, bu yüzden elle yazıldı.
uint64_t fnv1a(const std::string& s, uint64_t seed) {
  uint64_t h = seed;
  for (unsigned char c : s) {
    h ^= static_cast<uint64_t>(c);
    h *= 1099511628211ULL;
  }
  return h;
}

std::string encode(uint64_t value, int length) {
  std::string out(static_cast<size_t>(length), '0');
  for (int i = length - 1; i >= 0; i--) {
    out[static_cast<size_t>(i)] = kAlphabet[value % 32];
    value /= 32;
  }
  return out;
}

}  // namespace

std::string threadIdFor(const std::string& userA, const std::string& userB) {
  if (userA.empty() || userB.empty() || userA == userB) return {};

  // Sıra bağımsızlığı: küçük olan her zaman önce. Böylece threadIdFor(a,b) ile
  // threadIdFor(b,a) aynı kimliği üretir ve "aynı kişiyle iki sohbet" imkânsız olur.
  const std::string& first = userA < userB ? userA : userB;
  const std::string& second = userA < userB ? userB : userA;

  const uint64_t high = fnv1a(second, fnv1a(first, 1469598103934665603ULL));
  const uint64_t low = fnv1a(first + '\x1f' + second, high);
  return "T" + encode(high, 13) + encode(low, 12);
}

bool sanitizeMessageText(const std::string& raw, std::string& out) {
  auto isSpace = [](char ch) {
    return std::isspace(static_cast<unsigned char>(ch)) != 0;
  };

  size_t begin = 0;
  size_t end = raw.size();
  while (begin < end && isSpace(raw[begin])) begin++;
  while (end > begin && isSpace(raw[end - 1])) end--;
  if (begin >= end) return false;

  std::string trimmed = raw.substr(begin, end - begin);
  // Uzunluk aşımı hata değil, kırpmadır: uzun yazdı diye mesajı tamamen düşürmek
  // kullanıcı açısından sessizce kısaltmaktan daha kötü bir sonuç olurdu.
  if (trimmed.size() > kMaxMessageLength) trimmed.resize(kMaxMessageLength);
  out = std::move(trimmed);
  return true;
}

std::string Thread::other(const std::string& userId) const {
  if (userId == userA) return userB;
  if (userId == userB) return userA;
  return {};
}

bool Thread::hasUnread(const std::string& userId) const {
  if (lastAt <= 0) return false;
  // Kendi gönderdiğin mesaj okunmamış sayılmaz.
  if (!lastFromId.empty() && lastFromId == userId) return false;
  if (userId == userA) return lastAt > readA;
  if (userId == userB) return lastAt > readB;
  return false;
}

json::Value Message::toJson() const {
  json::Value v = json::Value::obj();
  v.set("id", id);
  v.set("threadId", threadId);
  v.set("fromId", fromId);
  v.set("toId", toId);
  v.set("text", text);
  v.set("at", at);
  return v;
}

Message Message::fromJson(const json::Value& v) {
  Message m;
  m.id = v["id"].asString();
  m.threadId = v["threadId"].asString();
  m.fromId = v["fromId"].asString();
  m.toId = v["toId"].asString();
  m.text = v["text"].asString();
  m.at = v["at"].asInt();
  return m;
}

json::Value Thread::toJson() const {
  json::Value v = json::Value::obj();
  v.set("id", id);
  v.set("userA", userA);
  v.set("userB", userB);
  v.set("lastText", lastText);
  v.set("lastFromId", lastFromId);
  v.set("lastAt", lastAt);
  v.set("messageCount", messageCount);
  v.set("readA", readA);
  v.set("readB", readB);
  return v;
}

Thread Thread::fromJson(const json::Value& v) {
  Thread t;
  t.id = v["id"].asString();
  t.userA = v["userA"].asString();
  t.userB = v["userB"].asString();
  t.lastText = v["lastText"].asString();
  t.lastFromId = v["lastFromId"].asString();
  t.lastAt = v["lastAt"].asInt();
  t.messageCount = v["messageCount"].asInt();
  t.readA = v["readA"].asInt();
  t.readB = v["readB"].asInt();
  return t;
}

}  // namespace hg::domain
