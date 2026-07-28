// Randevu alanı implementasyonu.
// Tüm zaman hesapları tam sayı aritmetiğiyle yapılır; saat dilimi veriden gelir.
// Negatif zaman damgalarında aşağı yuvarlama (floor) uygulanır.
// JSON serileştirme/çözümleme alan adlarıyla birebir eşleşir.

#include "domain/business/appointment.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace hg::domain {

namespace {

constexpr int64_t kMin = 60000;
constexpr int64_t kHour = 60 * kMin;
constexpr int64_t kDay = 24 * kHour;

// Aşağı yuvarlayan bölme (b > 0)
int64_t floorDiv(int64_t a, int64_t b) {
  int64_t q = a / b;
  int64_t r = a % b;
  if (r < 0) {
    q -= 1;
  }
  return q;
}

// Basit boşluk karakteri denetimi
bool isSpace(char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v';
}

std::string sanitizeString(const std::string& raw, size_t maxLen) {
  // Baştaki boşlukları at
  size_t start = 0;
  while (start < raw.size() && isSpace(raw[start])) {
    ++start;
  }
  // Sondaki boşlukları at
  size_t end = raw.size();
  while (end > start && isSpace(raw[end - 1])) {
    --end;
  }
  std::string result = raw.substr(start, end - start);

  // Uzunluk sınırı
  if (result.size() > maxLen) {
    result.resize(maxLen);
    // UTF‑8 güvenli kesme: son bayt bir devam baytı ise karakter başına çek
    while (!result.empty() &&
           (static_cast<unsigned char>(result.back()) & 0xC0) == 0x80) {
      result.pop_back();
    }
  }
  return result;
}

}  // namespace

// ──────────────────────────────── Durum adlandırma ────────────────────────────────

const char* statusName(AppointmentStatus s) {
  switch (s) {
    case AppointmentStatus::Requested:  return "requested";
    case AppointmentStatus::Confirmed:  return "confirmed";
    case AppointmentStatus::Completed:  return "completed";
    case AppointmentStatus::Cancelled:  return "cancelled";
  }
  return "requested";  // bilinmeyen değer
}

bool statusFromName(const std::string& name, AppointmentStatus& out) {
  if (name == "requested") { out = AppointmentStatus::Requested; return true; }
  if (name == "confirmed") { out = AppointmentStatus::Confirmed; return true; }
  if (name == "completed") { out = AppointmentStatus::Completed; return true; }
  if (name == "cancelled") { out = AppointmentStatus::Cancelled; return true; }
  return false;
}

const char* sourceName(AppointmentSource s) {
  switch (s) {
    case AppointmentSource::Business:  return "business";
    case AppointmentSource::Customer:  return "customer";
  }
  return "business";
}

bool sourceFromName(const std::string& name, AppointmentSource& out) {
  if (name == "business") { out = AppointmentSource::Business; return true; }
  if (name == "customer") { out = AppointmentSource::Customer; return true; }
  return false;
}

// ──────────────────────────────── Appointment ────────────────────────────────

bool Appointment::holdsSlot() const {
  return status == AppointmentStatus::Requested ||
         status == AppointmentStatus::Confirmed;
}

json::Value Appointment::toJson() const {
  json::Value obj = json::Value::obj();
  obj.set("id", json::Value(id));
  obj.set("businessId", json::Value(businessId));
  obj.set("customerId", json::Value(customerId));
  obj.set("customerName", json::Value(customerName));
  obj.set("phone", json::Value(phone));
  obj.set("service", json::Value(service));
  obj.set("note", json::Value(note));
  obj.set("at", json::Value(at));
  obj.set("priceKurus", json::Value(priceKurus));
  obj.set("status", json::Value(statusName(status)));
  obj.set("source", json::Value(sourceName(source)));
  obj.set("createdBy", json::Value(createdBy));
  obj.set("createdAt", json::Value(createdAt));
  return obj;
}

Appointment Appointment::fromJson(const json::Value& v) {
  Appointment a;
  a.id = v["id"].asString();
  a.businessId = v["businessId"].asString();
  a.customerId = v["customerId"].asString();
  a.customerName = v["customerName"].asString();
  a.phone = v["phone"].asString();
  a.service = v["service"].asString();
  a.note = v["note"].asString();
  a.at = v["at"].asInt(0);
  a.priceKurus = v["priceKurus"].asInt(0);
  a.createdBy = v["createdBy"].asString();
  a.createdAt = v["createdAt"].asInt(0);

  if (v.has("status")) {
    AppointmentStatus s;
    if (statusFromName(v["status"].asString(), s)) {
      a.status = s;
    }
  }
  if (v.has("source")) {
    AppointmentSource src;
    if (sourceFromName(v["source"].asString(), src)) {
      a.source = src;
    }
  }
  return a;
}

// ──────────────────────────────── WorkingHours ────────────────────────────────

bool WorkingHours::isValid() const {
  if (startHour < 0 || endHour > 24 || startHour >= endHour) return false;
  if (slotMinutes < 5 || slotMinutes > 480) return false;
  if (tzOffsetMinutes < -840 || tzOffsetMinutes > 840) return false;
  for (int d : closedDays) {
    if (d < 0 || d > 6) return false;
  }
  // En az bir slot sığıyor mu?
  int totalMinutes = (endHour - startHour) * 60;
  if (totalMinutes < slotMinutes) return false;
  return true;
}

bool WorkingHours::isClosedOn(int weekday) const {
  return std::find(closedDays.begin(), closedDays.end(), weekday) != closedDays.end();
}

std::vector<int> WorkingHours::slotsOfDay() const {
  std::vector<int> slots;
  if (!isValid()) return slots;

  int startMin = startHour * 60;
  int endMin = endHour * 60;
  for (int t = startMin; t + slotMinutes <= endMin; t += slotMinutes) {
    slots.push_back(t);
  }
  return slots;
}

json::Value WorkingHours::toJson() const {
  json::Value obj = json::Value::obj();
  obj.set("startHour", json::Value(startHour));
  obj.set("endHour", json::Value(endHour));
  obj.set("slotMinutes", json::Value(slotMinutes));
  obj.set("tzOffsetMinutes", json::Value(tzOffsetMinutes));

  json::Value arr = json::Value::arr();
  for (int d : closedDays) {
    arr.push(json::Value(d));
  }
  obj.set("closedDays", std::move(arr));
  return obj;
}

WorkingHours WorkingHours::fromJson(const json::Value& v) {
  WorkingHours wh;
  wh.startHour = static_cast<int>(v["startHour"].asInt(9));
  wh.endHour = static_cast<int>(v["endHour"].asInt(19));
  wh.slotMinutes = static_cast<int>(v["slotMinutes"].asInt(60));
  wh.tzOffsetMinutes = static_cast<int>(v["tzOffsetMinutes"].asInt(180));

  const json::Array& arr = v["closedDays"].asArray();
  wh.closedDays.clear();
  for (const json::Value& item : arr) {
    wh.closedDays.push_back(static_cast<int>(item.asInt(0)));
  }
  // Eğer dizi yoksa varsayılanı koru (Pazar kapalı)
  if (wh.closedDays.empty() && !v.has("closedDays")) {
    wh.closedDays = {6};
  }
  return wh;
}

// ──────────────────────────────── Zaman yardımcıları ────────────────────────────────

int64_t dayStart(int64_t ms, int tzOffsetMinutes) {
  int64_t localMs = ms + static_cast<int64_t>(tzOffsetMinutes) * 60000;
  int64_t day = floorDiv(localMs, kDay);
  return day * kDay - static_cast<int64_t>(tzOffsetMinutes) * 60000;
}

int weekdayIndex(int64_t ms, int tzOffsetMinutes) {
  int64_t localMs = ms + static_cast<int64_t>(tzOffsetMinutes) * 60000;
  int64_t days = floorDiv(localMs, kDay);
  int64_t wd = (days + 3) % 7;
  if (wd < 0) wd += 7;
  return static_cast<int>(wd);
}

// ──────────────────────────────── Slot sorgulamaları ────────────────────────────────

bool isValidSlot(const WorkingHours& wh, int64_t at) {
  auto slots = slotsForDay(wh, at);
  return std::find(slots.begin(), slots.end(), at) != slots.end();
}

std::vector<int64_t> slotsForDay(const WorkingHours& wh, int64_t dayMs) {
  std::vector<int64_t> result;
  if (!wh.isValid()) return result;

  int64_t start = dayStart(dayMs, wh.tzOffsetMinutes);
  int wday = weekdayIndex(start, wh.tzOffsetMinutes);
  if (wh.isClosedOn(wday)) return result;

  for (int m : wh.slotsOfDay()) {
    result.push_back(start + static_cast<int64_t>(m) * 60000);
  }
  return result;
}

bool slotTaken(const std::vector<Appointment>& existing, int64_t at) {
  for (const auto& a : existing) {
    if (a.holdsSlot() && a.at == at) {
      return true;
    }
  }
  return false;
}

std::vector<int64_t> freeSlots(const WorkingHours& wh, int64_t dayMs,
                               const std::vector<Appointment>& existing,
                               int64_t now) {
  std::vector<int64_t> free;
  auto slots = slotsForDay(wh, dayMs);
  for (int64_t s : slots) {
    if (s >= now && !slotTaken(existing, s)) {
      free.push_back(s);
    }
  }
  return free;
}

// ──────────────────────────────── Durum geçişleri ────────────────────────────────

bool canTransition(AppointmentStatus from, AppointmentStatus to) {
  if (from == to) return false;
  switch (from) {
    case AppointmentStatus::Requested:
      return to == AppointmentStatus::Confirmed ||
             to == AppointmentStatus::Cancelled;
    case AppointmentStatus::Confirmed:
      return to == AppointmentStatus::Completed ||
             to == AppointmentStatus::Cancelled;
    case AppointmentStatus::Completed:
    case AppointmentStatus::Cancelled:
      return false;
  }
  return false;
}

// ──────────────────────────────── Metin temizliği ────────────────────────────────

std::string sanitizeNote(const std::string& raw) {
  return sanitizeString(raw, kMaxNoteLength);
}

std::string sanitizeService(const std::string& raw) {
  return sanitizeString(raw, kMaxServiceLength);
}

}  // namespace hg::domain
