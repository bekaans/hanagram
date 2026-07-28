// Hanagram — satış alanı implementasyonu
//
// Satış kalemlerinden toplam hesaplama, JSON dönüşümü ve
// yardımcı fonksiyonlar. Para kuruştur (tam sayı).
#include "sale.hpp"

namespace hg::domain {

// ── SaleItem ──

json::Value SaleItem::toJson() const {
  json::Value j = json::Value::obj();
  j.set("productId", productId);
  j.set("name", name);
  j.set("quantity", quantity);
  j.set("unitPriceKurus", unitPriceKurus);
  return j;
}

SaleItem SaleItem::fromJson(const json::Value& v) {
  SaleItem item;
  item.productId = v["productId"].asString();
  item.name = v["name"].asString();
  item.quantity = v["quantity"].asInt();
  item.unitPriceKurus = v["unitPriceKurus"].asInt();
  return item;
}

// ── PaymentMethod ──

const char* paymentMethodToString(PaymentMethod m) {
  switch (m) {
    case PaymentMethod::kCash:     return "cash";
    case PaymentMethod::kCard:     return "card";
    case PaymentMethod::kTransfer: return "transfer";
    case PaymentMethod::kOther:    return "other";
  }
  return "other";
}

PaymentMethod paymentMethodFromString(const std::string& s) {
  if (s == "cash")     return PaymentMethod::kCash;
  if (s == "card")     return PaymentMethod::kCard;
  if (s == "transfer") return PaymentMethod::kTransfer;
  return PaymentMethod::kOther;
}

// ── Sale ──

json::Value Sale::toJson() const {
  json::Value j = json::Value::obj();
  j.set("id", id);
  j.set("businessId", businessId);
  j.set("customerId", customerId);
  j.set("customerName", customerName);
  json::Value itemsArr = json::Value::arr();
  for (const auto& item : items) {
    itemsArr.push(item.toJson());
  }
  j.set("items", itemsArr);
  j.set("totalKurus", totalKurus);
  j.set("paymentMethod", paymentMethodToString(paymentMethod));
  j.set("note", note);
  j.set("source", source);
  j.set("createdAt", createdAt);
  return j;
}

Sale Sale::fromJson(const json::Value& v) {
  Sale s;
  s.id = v["id"].asString();
  s.businessId = v["businessId"].asString();
  s.customerId = v["customerId"].asString();
  s.customerName = v["customerName"].asString();
  const auto& itemsArr = v["items"].asArray();
  s.items.reserve(itemsArr.size());
  for (size_t i = 0; i < itemsArr.size(); ++i) {
    s.items.push_back(SaleItem::fromJson(itemsArr[i]));
  }
  s.totalKurus = v["totalKurus"].asInt();
  s.paymentMethod = paymentMethodFromString(v["paymentMethod"].asString());
  s.note = v["note"].asString();
  s.source = v["source"].asString();
  s.createdAt = v["createdAt"].asInt();
  return s;
}

void computeSaleTotal(Sale& s) {
  int64_t total = 0;
  for (const auto& item : s.items) {
    total += item.quantity * item.unitPriceKurus;
  }
  s.totalKurus = total;
}

std::string sanitizeSaleNote(const std::string& raw) {
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
  while (byteLen < trimmed.size() && charCount < kMaxSaleNoteLength) {
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

}  // namespace hg::domain
