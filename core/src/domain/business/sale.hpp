// Hanagram — satış alanı (SÖZLEŞME)
//
// Bir işletmenin yaptığı_satış_işlemini temsil eder. Satış, bir müşteriye
// (isteğe bağlı) yapılan bir veya birden fazla ürünü kapsar.
//
// Tasarım kararları:
//  - Para birimi kuruştur (tam sayı). Toplam kalemlerden hesaplanır.
//  - Her kalemin birim fiyatı o ana aittir; ürün fiyatı değişse bile geçmiş
//    satış kayıtları değişmez.
//  - `source`, satışın randevudan mı yoksa doğrudan mı geldiğini gösterir.
//  - Bu modül ürün ve müşteri alanlarını BİLMEZ; aralarındaki bağı API kurar.
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "../../util/json.hpp"

namespace hg::domain {

/// Tek bir satış kalemi.
struct SaleItem {
  std::string productId;
  std::string name;              // satış anındaki ürün adı (denormalize)
  int64_t quantity = 0;
  int64_t unitPriceKurus = 0;

  json::Value toJson() const;
  static SaleItem fromJson(const json::Value& v);
};

enum class PaymentMethod : uint8_t {
  kCash = 0,
  kCard = 1,
  kTransfer = 2,
  kOther = 3,
};

/// PaymentMethod'u string'e çevirir.
const char* paymentMethodToString(PaymentMethod m);

/// String'den PaymentMethod'a çevirir. Geçersizse kOther döner.
PaymentMethod paymentMethodFromString(const std::string& s);

struct Sale {
  std::string id;
  std::string businessId;
  std::string customerId;        // boş olabilir (yoldan geçen)
  std::string customerName;      // gösterim için çözümlenmiş
  std::vector<SaleItem> items;
  int64_t totalKurus = 0;        // kalemlerin toplamı (hesaplanır)
  PaymentMethod paymentMethod = PaymentMethod::kCash;
  std::string note;
  std::string source;            // "direct" | "appointment"
  int64_t createdAt = 0;

  json::Value toJson() const;
  static Sale fromJson(const json::Value& v);
};

/// Satış kalemlerinden toplamı hesaplar ve totalKurus'a yazar.
void computeSaleTotal(Sale& s);

/// Satış notunu doğrular ve kırpılmış hâlini verir.
std::string sanitizeSaleNote(const std::string& raw);

constexpr size_t kMaxSaleNoteLength = 500;

}  // namespace hg::domain
