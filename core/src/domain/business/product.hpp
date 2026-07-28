// Hanagram — ürün alanı (SÖZLEŞME)
//
// İşletmenin sattığı ürün/hizmetleri temsil eder. Her ürün bir işletmeye
// aittir; birden fazla işletme aynı isimde ürün tanımlayabilir.
//
// Tasarım kararları:
//  - Para birimi kuruştur (tam sayı). Kayan nokta kullanılmaz.
//  - `active` alanı silme yerine devre dışı bırakma sağlar: pasif ürünler
//    listelenmez ama geçmiş satış referanslarını bozmaz.
//  - Arama Türkçe duyarlıdır (foldForSearch).
//  - Bu modül müşteri ve satış alanlarını BİLMEZ.
#pragma once

#include <cstdint>
#include <string>

#include "../../util/json.hpp"

namespace hg::domain {

struct Product {
  std::string id;
  std::string businessId;
  std::string name;
  std::string description;
  int64_t priceKurus = 0;
  std::string category;
  bool active = true;
  int64_t createdAt = 0;
  int64_t updatedAt = 0;

  json::Value toJson() const;
  static Product fromJson(const json::Value& v);
};

/// Ürün adını doğrular ve kırpılmış hâlini verir.
/// Boş ad geçersizdir. En fazla kMaxProductNameLength karakter.
bool sanitizeProductName(const std::string& raw, std::string& out);

/// Kategoriyi normalize eder: foldForSearch uygulanır, boşsa geçersiz.
/// En fazla kMaxCategoryLength karakter.
bool sanitizeCategory(const std::string& raw, std::string& out);

/// Ürün açıklamasını kırpılmış hâlinde döner. Boş geçerlidir.
std::string sanitizeDescription(const std::string& raw);

/// Arama eşleşmesi. Sorgu boşsa tüm ürünler gösterilir.
/// foldForSearch(query), foldForSearch(name) içinde geçiyorsa eşleşir.
bool matchesProductQuery(const Product& p, const std::string& query);

constexpr size_t kMaxProductNameLength = 80;
constexpr size_t kMaxDescriptionLength = 500;
constexpr size_t kMaxCategoryLength = 40;

}  // namespace hg::domain
