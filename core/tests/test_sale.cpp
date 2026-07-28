// Satış alanı testleri
#include "domain/business/sale.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::domain;

namespace {

SaleItem makeItem(const std::string& name, int64_t qty, int64_t price) {
  SaleItem item;
  item.productId = "p1";
  item.name = name;
  item.quantity = qty;
  item.unitPriceKurus = price;
  return item;
}

Sale sample() {
  Sale s;
  s.id = "s1";
  s.businessId = "b1";
  s.customerId = "c1";
  s.customerName = "Ahmet";
  s.items.push_back(makeItem("Kahve", 2, 15000));
  s.items.push_back(makeItem("Poğaça", 1, 8000));
  s.paymentMethod = PaymentMethod::kCard;
  s.note = "Masaya servis";
  s.source = "direct";
  s.createdAt = 1000;
  computeSaleTotal(s);
  return s;
}

}  // namespace

// ── Toplam hesaplama ──

TEST(computeSaleToplam_dogru) {
  Sale s = sample();
  // 2 * 15000 + 1 * 8000 = 38000
  CHECK_EQ(s.totalKurus, int64_t{38000});
}

TEST(compareSaleToplam_bos) {
  Sale s;
  s.id = "s2";
  s.businessId = "b1";
  computeSaleTotal(s);
  CHECK_EQ(s.totalKurus, int64_t{0});
}

// ── PaymentMethod ──

TEST(paymentMethod_string_donusumu) {
  CHECK_EQ(std::string(paymentMethodToString(PaymentMethod::kCash)), std::string("cash"));
  CHECK_EQ(std::string(paymentMethodToString(PaymentMethod::kCard)), std::string("card"));
  CHECK_EQ(std::string(paymentMethodToString(PaymentMethod::kTransfer)), std::string("transfer"));
  CHECK_EQ(std::string(paymentMethodToString(PaymentMethod::kOther)), std::string("other"));
}

TEST(paymentMethod_fromString) {
  CHECK_EQ(paymentMethodFromString("cash"), PaymentMethod::kCash);
  CHECK_EQ(paymentMethodFromString("card"), PaymentMethod::kCard);
  CHECK_EQ(paymentMethodFromString("transfer"), PaymentMethod::kTransfer);
  CHECK_EQ(paymentMethodFromString("bogus"), PaymentMethod::kOther);
}

// ── SaleItem JSON ──

TEST(saleItem_json_donusumu) {
  SaleItem item = makeItem("Çay", 3, 10000);
  json::Value j = item.toJson();
  SaleItem item2 = SaleItem::fromJson(j);
  CHECK_EQ(item2.name, item.name);
  CHECK_EQ(item2.quantity, item.quantity);
  CHECK_EQ(item2.unitPriceKurus, item.unitPriceKurus);
}

// ── Sale JSON ──

TEST(sale_json_donusumu) {
  Sale s = sample();
  json::Value j = s.toJson();
  Sale s2 = Sale::fromJson(j);
  CHECK_EQ(s2.id, s.id);
  CHECK_EQ(s2.businessId, s.businessId);
  CHECK_EQ(s2.customerName, s.customerName);
  CHECK_EQ(s2.totalKurus, s.totalKurus);
  CHECK_EQ(s2.items.size(), s.items.size());
  CHECK_EQ(s2.paymentMethod, s.paymentMethod);
}

// ── Not doğrulama ──

TEST(sanitizeSaleNote_normal) {
  CHECK_EQ(sanitizeSaleNote("Masada"), std::string("Masada"));
}

TEST(sanitizeSaleNote_bos) {
  CHECK(sanitizeSaleNote("").empty());
  CHECK(sanitizeSaleNote("   ").empty());
}

TEST(sanitizeSaleNote_basi_sondaki_bosluk) {
  CHECK_EQ(sanitizeSaleNote("  Not  "), std::string("Not"));
}
