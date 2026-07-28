// Ürün alanı testleri
#include "domain/business/product.hpp"
#include "domain/business/customer.hpp"  // foldForSearch
#include "test.hpp"

using namespace hg;
using namespace hg::domain;

namespace {

Product sample() {
  Product p;
  p.id = "p1";
  p.businessId = "b1";
  p.name = "Kahve";
  p.description = "Taze çekilmiş kahve";
  p.priceKurus = 15000;
  p.category = "İçecek";
  p.active = true;
  p.createdAt = 1000;
  p.updatedAt = 1000;
  return p;
}

}  // namespace

// ── Doğrulama ──

TEST(sanitizeProductName_normal) {
  std::string out;
  CHECK(sanitizeProductName("Kahve", out));
  CHECK_EQ(out, std::string("Kahve"));
}

TEST(sanitizeProductName_bos_gecersiz) {
  std::string out;
  CHECK(!sanitizeProductName("", out));
  CHECK(!sanitizeProductName("   ", out));
}

TEST(sanitizeProductName_basi_sondaki_bosluk) {
  std::string out;
  CHECK(sanitizeProductName("  Latte  ", out));
  CHECK_EQ(out, std::string("Latte"));
}

TEST(sanitizeProductName_max_uzunluk) {
  std::string longName(200, 'A');
  std::string out;
  CHECK(sanitizeProductName(longName, out));
  CHECK(out.size() <= kMaxProductNameLength);
}

TEST(sanitizeCategory_normal) {
  std::string out;
  CHECK(sanitizeCategory("İçecek", out));
  CHECK(!out.empty());
}

TEST(sanitizeCategory_bos_gecersiz) {
  std::string out;
  CHECK(!sanitizeCategory("", out));
  CHECK(!sanitizeCategory("   ", out));
}

TEST(sanitizeDescription_bos_gecerli) {
  CHECK(sanitizeDescription("").empty());
  CHECK(sanitizeDescription("   ").empty());
}

TEST(sanitizeDescription_normal) {
  std::string desc = sanitizeDescription("Güzel bir ürün");
  CHECK_EQ(desc, std::string("Güzel bir ürün"));
}

// ── Arama ──

TEST(matchesProductQuery_bos_sorgu_hepsini_bulur) {
  Product p = sample();
  CHECK(matchesProductQuery(p, ""));
  CHECK(matchesProductQuery(p, "   "));
}

TEST(matchesProductQuery_isim_eslesmesi) {
  Product p = sample();
  CHECK(matchesProductQuery(p, "kahve"));
  CHECK(matchesProductQuery(p, "KAHVE"));
  CHECK(matchesProductQuery(p, "ahv"));
}

TEST(matchesProductQuery_turkce_duyarlilik) {
  Product p = sample();
  p.name = "Şıra";
  CHECK(matchesProductQuery(p, "sira"));
  CHECK(matchesProductQuery(p, "ŞIRA"));
}

TEST(matchesProductQuery_eslesmeyen) {
  Product p = sample();
  CHECK(!matchesProductQuery(p, "su"));
}

// ── JSON ──

TEST(product_json_donusumu) {
  Product p = sample();
  json::Value j = p.toJson();
  Product p2 = Product::fromJson(j);
  CHECK_EQ(p2.id, p.id);
  CHECK_EQ(p2.name, p.name);
  CHECK_EQ(p2.priceKurus, p.priceKurus);
  CHECK_EQ(p2.category, p.category);
  CHECK_EQ(p2.active, p.active);
}
