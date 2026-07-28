// Hanagram — işletme API'si: randevu takvimi ve müşteri defteri
//
// Bu katman KARAR VERMEZ, yönlendirir: doğrulama ve hesap domain/business
// içindedir, buradaki kod yalnızca yükü okur, alan fonksiyonlarını çağırır,
// depoya yazar ve sonuç sözleşmesine çevirir.
//
// Yetki kuralı: her metot `businessId` ister ve kaydın o işletmeye ait olduğunu
// doğrular. Başka bir işletmenin kaydı BULUNAMADI sayılır — "yetkin yok" demek
// kaydın varlığını sızdırır.
#include <algorithm>
#include <limits>

#include "../domain/business/ad.hpp"
#include "../domain/business/appointment.hpp"
#include "../domain/business/customer.hpp"
#include "../domain/business/product.hpp"
#include "../domain/business/sale.hpp"
#include "../kernel/runtime.hpp"

namespace hg::kernel {

namespace {

using domain::Ad;
using domain::AdStatus;
using domain::Appointment;
using domain::AppointmentSource;
using domain::AppointmentStatus;
using domain::Customer;
using domain::Product;
using domain::Sale;
using domain::SaleItem;
using domain::WorkingHours;

// İşletme hesabını doğrular. Sorun varsa hata kodu, yoksa boş dizge.
std::string checkBusiness(Store& store, const std::string& businessId) {
  if (businessId.empty()) return "ERR_USER_NOT_FOUND";
  const json::Value u = store.get(coll::kUsers, businessId);
  if (u.isNull()) return "ERR_USER_NOT_FOUND";
  if (u["accountType"].asString() != "business") return "ERR_NOT_BUSINESS";
  return {};
}

// Kaydedilmiş çalışma düzeni; hiç ayarlanmadıysa varsayılan.
WorkingHours hoursOf(Store& store, const std::string& businessId) {
  const json::Value v = store.get(coll::kBusinessHours, businessId);
  return v.isNull() ? WorkingHours{} : WorkingHours::fromJson(v);
}

std::vector<Appointment> appointmentsOf(Store& store, const std::string& businessId) {
  std::vector<Appointment> list;
  for (const Record& r : store.where(coll::kAppointments,
                                     [&](const json::Value& v) {
                                       return v["businessId"].asString() == businessId;
                                     })) {
    list.push_back(Appointment::fromJson(r.data));
  }
  return list;
}

std::vector<Customer> customersOf(Store& store, const std::string& businessId) {
  std::vector<Customer> list;
  for (const Record& r : store.where(coll::kCustomers,
                                     [&](const json::Value& v) {
                                       return v["businessId"].asString() == businessId;
                                     })) {
    list.push_back(Customer::fromJson(r.data));
  }
  return list;
}

std::vector<Product> productsOf(Store& store, const std::string& businessId) {
  std::vector<Product> list;
  for (const Record& r : store.where(coll::kProducts,
                                     [&](const json::Value& v) {
                                       return v["businessId"].asString() == businessId;
                                     })) {
    list.push_back(Product::fromJson(r.data));
  }
  return list;
}

std::vector<Sale> salesOf(Store& store, const std::string& businessId) {
  std::vector<Sale> list;
  for (const Record& r : store.where(coll::kSales,
                                     [&](const json::Value& v) {
                                       return v["businessId"].asString() == businessId;
                                     })) {
    list.push_back(Sale::fromJson(r.data));
  }
  return list;
}

std::vector<Ad> adsOf(Store& store, const std::string& businessId) {
  std::vector<Ad> list;
  for (const Record& r : store.where(coll::kAds,
                                     [&](const json::Value& v) {
                                       return v["businessId"].asString() == businessId;
                                     })) {
    list.push_back(Ad::fromJson(r.data));
  }
  return list;
}

int readInt(const json::Value& v, int def) {
  return v.isNull() ? def : static_cast<int>(v.asInt(def));
}

// Etiket listesini normalize ederek yazar: tekrarlar elenir, sıra korunur.
void setTags(Customer& c, const json::Value& tags) {
  c.tags.clear();
  for (const json::Value& t : tags.asArray()) domain::addTag(c, t.asString());
}

}  // namespace

void registerBusinessApi(Runtime& rt) {
  // ——— Çalışma saatleri ———
  rt.registerMethod("business.setHours", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    WorkingHours wh;
    wh.startHour = readInt(p["startHour"], wh.startHour);
    wh.endHour = readInt(p["endHour"], wh.endHour);
    wh.slotMinutes = readInt(p["slotMinutes"], wh.slotMinutes);
    wh.tzOffsetMinutes = readInt(p["tzOffsetMinutes"], wh.tzOffsetMinutes);
    if (p.has("closedDays")) {
      wh.closedDays.clear();
      for (const json::Value& d : p["closedDays"].asArray()) {
        wh.closedDays.push_back(static_cast<int>(d.asInt()));
      }
    }
    if (!wh.isValid()) return json::fail("ERR_INVALID_HOURS");

    ctx.store.put(coll::kBusinessHours, biz, wh.toJson());
    return json::ok(wh.toJson());
  });

  rt.registerMethod("business.hours", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);
    return json::ok(hoursOf(ctx.store, biz).toJson());
  });

  // ——— Boş slotlar ———
  rt.registerMethod("appointment.slots", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    json::Value slots = json::Value::arr();
    for (int64_t t : domain::freeSlots(hoursOf(ctx.store, biz), p["dayMs"].asInt(),
                                       appointmentsOf(ctx.store, biz), ctx.clock.now())) {
      slots.push(t);
    }
    json::Value d = json::Value::obj();
    d.set("slots", slots);
    return json::ok(d);
  });

  // ——— Randevu aç ———
  rt.registerMethod("appointment.create", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    std::string name;
    if (!domain::sanitizeName(p["customerName"].asString(), name)) {
      return json::fail("ERR_NAME_REQUIRED");
    }
    std::string phone;
    if (!domain::normalizePhone(p["phone"].asString(), phone)) {
      return json::fail("ERR_INVALID_PHONE");
    }

    const int64_t at = p["at"].asInt();
    if (!domain::isValidSlot(hoursOf(ctx.store, biz), at)) {
      return json::fail("ERR_SLOT_INVALID");
    }
    if (at < ctx.clock.now()) return json::fail("ERR_PAST");
    if (domain::slotTaken(appointmentsOf(ctx.store, biz), at)) {
      return json::fail("ERR_SLOT_TAKEN");
    }

    // Kaynağı müşteri olan randevu ONAY BEKLER; işletme kendisi eklerse zaten
    // takvimine bakarak eklemiştir, ayrıca onaylatmanın anlamı yok.
    AppointmentSource source = AppointmentSource::Business;
    domain::sourceFromName(p["source"].asString(), source);

    Appointment a;
    a.id = ctx.ids.next(ctx.clock.now());
    a.businessId = biz;
    a.customerId = p["customerId"].asString();
    a.customerName = name;
    a.phone = phone;
    a.service = domain::sanitizeService(p["service"].asString());
    a.note = domain::sanitizeNote(p["note"].asString());
    a.at = at;
    a.priceKurus = p["priceKurus"].asInt();
    a.source = source;
    a.status = source == AppointmentSource::Customer ? AppointmentStatus::Requested
                                                     : AppointmentStatus::Confirmed;
    a.createdBy = p["createdBy"].asString();
    a.createdAt = ctx.clock.now();

    ctx.store.put(coll::kAppointments, a.id, a.toJson());
    return json::ok(a.toJson());
  });

  // ——— Randevu listesi ———
  rt.registerMethod("appointment.list", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const bool hasFrom = p.has("fromMs");
    const bool hasTo = p.has("toMs");
    const int64_t from = p["fromMs"].asInt();
    const int64_t to = p["toMs"].asInt();

    std::vector<Appointment> list = appointmentsOf(ctx.store, biz);
    std::sort(list.begin(), list.end(),
              [](const Appointment& x, const Appointment& y) { return x.at < y.at; });

    json::Value items = json::Value::arr();
    for (const Appointment& a : list) {
      if (hasFrom && a.at < from) continue;
      if (hasTo && a.at >= to) continue;  // üst sınır dışarıda kalır
      items.push(a.toJson());
    }
    json::Value d = json::Value::obj();
    d.set("items", items);
    return json::ok(d);
  });

  // ——— Durum değiştir ———
  rt.registerMethod("appointment.setStatus", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const json::Value v = ctx.store.get(coll::kAppointments,
                                        p["appointmentId"].asString());
    if (v.isNull()) return json::fail("ERR_APPOINTMENT_NOT_FOUND");
    Appointment a = Appointment::fromJson(v);
    if (a.businessId != biz) return json::fail("ERR_APPOINTMENT_NOT_FOUND");

    AppointmentStatus to = AppointmentStatus::Requested;
    if (!domain::statusFromName(p["status"].asString(), to)) {
      return json::fail("ERR_STATUS_INVALID");
    }
    if (!domain::canTransition(a.status, to)) return json::fail("ERR_BAD_TRANSITION");

    a.status = to;
    ctx.store.put(coll::kAppointments, a.id, a.toJson());

    // Ziyaret sayacı olay anında işlenir; her sorguda randevu geçmişi taranmaz.
    if (to == AppointmentStatus::Completed && !a.customerId.empty()) {
      const json::Value cv = ctx.store.get(coll::kCustomers, a.customerId);
      if (!cv.isNull()) {
        Customer c = Customer::fromJson(cv);
        domain::recordVisit(c, a.at, a.priceKurus);
        ctx.store.put(coll::kCustomers, c.id, c.toJson());
      }
    }
    return json::ok(a.toJson());
  });

  // ——— Müşteri ekle ———
  rt.registerMethod("customer.create", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    std::string name;
    if (!domain::sanitizeName(p["name"].asString(), name)) {
      return json::fail("ERR_NAME_REQUIRED");
    }
    std::string phone;
    if (!domain::normalizePhone(p["phone"].asString(), phone)) {
      return json::fail("ERR_INVALID_PHONE");
    }
    const std::string email = p["email"].asString();
    if (!domain::isValidEmail(email)) return json::fail("ERR_INVALID_EMAIL");

    // Tekillik anahtarı telefondur — aynı numara iki kez deftere girmez.
    // Telefonsuz kayıtlar bu kurala takılmaz; ayırt edecek bilgi yoktur.
    if (!phone.empty()) {
      for (const Customer& c : customersOf(ctx.store, biz)) {
        if (c.phone == phone) return json::fail("ERR_CUSTOMER_EXISTS");
      }
    }

    Customer c;
    c.id = ctx.ids.next(ctx.clock.now());
    c.businessId = biz;
    c.name = name;
    c.phone = phone;
    c.email = email;
    c.note = domain::sanitizeNote(p["note"].asString());
    c.linkedUserId = p["linkedUserId"].asString();
    c.createdAt = ctx.clock.now();
    if (p.has("tags")) setTags(c, p["tags"]);

    ctx.store.put(coll::kCustomers, c.id, c.toJson());
    return json::ok(c.toJson());
  });

  // ——— Müşteri listesi ———
  rt.registerMethod("customer.list", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const std::string query = p["query"].asString();
    std::vector<Customer> hits;
    for (const Customer& c : customersOf(ctx.store, biz)) {
      if (domain::matchesQuery(c, query)) hits.push_back(c);
    }
    std::sort(hits.begin(), hits.end(), [](const Customer& x, const Customer& y) {
      return domain::foldForSearch(x.name) < domain::foldForSearch(y.name);
    });

    // Toplam, kırpmadan ÖNCE sayılır: arayüz "50 sonuçtan 20'si" diyebilsin.
    const int64_t total = static_cast<int64_t>(hits.size());
    const size_t limit =
        static_cast<size_t>(p.has("limit") ? p["limit"].asInt(50) : int64_t{50});

    json::Value items = json::Value::arr();
    for (size_t i = 0; i < hits.size() && i < limit; ++i) items.push(hits[i].toJson());

    json::Value d = json::Value::obj();
    d.set("items", items);
    d.set("total", total);
    return json::ok(d);
  });

  // ——— Müşteri güncelle ———
  rt.registerMethod("customer.update", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const json::Value v = ctx.store.get(coll::kCustomers, p["customerId"].asString());
    if (v.isNull()) return json::fail("ERR_CUSTOMER_NOT_FOUND");
    Customer c = Customer::fromJson(v);
    if (c.businessId != biz) return json::fail("ERR_CUSTOMER_NOT_FOUND");

    // Yalnızca GÖNDERİLEN alanlar değişir; olmayan anahtar "boşalt" demek değildir.
    if (p.has("name")) {
      std::string name;
      if (!domain::sanitizeName(p["name"].asString(), name)) {
        return json::fail("ERR_NAME_REQUIRED");
      }
      c.name = name;
    }
    if (p.has("phone")) {
      std::string phone;
      if (!domain::normalizePhone(p["phone"].asString(), phone)) {
        return json::fail("ERR_INVALID_PHONE");
      }
      c.phone = phone;
    }
    if (p.has("email")) {
      const std::string email = p["email"].asString();
      if (!domain::isValidEmail(email)) return json::fail("ERR_INVALID_EMAIL");
      c.email = email;
    }
    if (p.has("note")) c.note = domain::sanitizeNote(p["note"].asString());
    if (p.has("linkedUserId")) c.linkedUserId = p["linkedUserId"].asString();
    if (p.has("tags")) setTags(c, p["tags"]);

    ctx.store.put(coll::kCustomers, c.id, c.toJson());
    return json::ok(c.toJson());
  });

  // ——— Ürün ekle ———
  rt.registerMethod("product.create", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    std::string name;
    if (!domain::sanitizeProductName(p["name"].asString(), name)) {
      return json::fail("ERR_NAME_REQUIRED");
    }
    const int64_t price = p["priceKurus"].asInt();
    if (price < 0) return json::fail("ERR_INVALID_PRICE");

    std::string category;
    if (p.has("category") && !p["category"].asString().empty()) {
      if (!domain::sanitizeCategory(p["category"].asString(), category)) {
        return json::fail("ERR_INVALID_CATEGORY");
      }
    }

    Product prod;
    prod.id = ctx.ids.next(ctx.clock.now());
    prod.businessId = biz;
    prod.name = name;
    prod.description = domain::sanitizeDescription(p["description"].asString());
    prod.priceKurus = price;
    prod.category = category;
    prod.active = true;
    prod.createdAt = ctx.clock.now();
    prod.updatedAt = prod.createdAt;

    ctx.store.put(coll::kProducts, prod.id, prod.toJson());
    return json::ok(prod.toJson());
  });

  // ——— Ürün listesi ———
  rt.registerMethod("product.list", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const std::string query = p["query"].asString();
    std::vector<Product> hits;
    for (const Product& pr : productsOf(ctx.store, biz)) {
      if (!pr.active) continue;
      if (domain::matchesProductQuery(pr, query)) hits.push_back(pr);
    }
    std::sort(hits.begin(), hits.end(), [](const Product& x, const Product& y) {
      return domain::foldForSearch(x.name) < domain::foldForSearch(y.name);
    });

    const int64_t total = static_cast<int64_t>(hits.size());
    const size_t limit =
        static_cast<size_t>(p.has("limit") ? p["limit"].asInt(50) : int64_t{50});

    json::Value items = json::Value::arr();
    for (size_t i = 0; i < hits.size() && i < limit; ++i) items.push(hits[i].toJson());

    json::Value d = json::Value::obj();
    d.set("items", items);
    d.set("total", total);
    return json::ok(d);
  });

  // ——— Ürün güncelle ———
  rt.registerMethod("product.update", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const json::Value v = ctx.store.get(coll::kProducts, p["productId"].asString());
    if (v.isNull()) return json::fail("ERR_PRODUCT_NOT_FOUND");
    Product prod = Product::fromJson(v);
    if (prod.businessId != biz) return json::fail("ERR_PRODUCT_NOT_FOUND");

    if (p.has("name")) {
      std::string name;
      if (!domain::sanitizeProductName(p["name"].asString(), name)) {
        return json::fail("ERR_NAME_REQUIRED");
      }
      prod.name = name;
    }
    if (p.has("description")) {
      prod.description = domain::sanitizeDescription(p["description"].asString());
    }
    if (p.has("priceKurus")) {
      const int64_t price = p["priceKurus"].asInt();
      if (price < 0) return json::fail("ERR_INVALID_PRICE");
      prod.priceKurus = price;
    }
    if (p.has("category")) {
      std::string category;
      if (p["category"].asString().empty()) {
        prod.category.clear();
      } else if (!domain::sanitizeCategory(p["category"].asString(), category)) {
        return json::fail("ERR_INVALID_CATEGORY");
      } else {
        prod.category = category;
      }
    }
    if (p.has("active")) prod.active = p["active"].asBool();
    prod.updatedAt = ctx.clock.now();

    ctx.store.put(coll::kProducts, prod.id, prod.toJson());
    return json::ok(prod.toJson());
  });

  // ——— Satış kaydet ———
  rt.registerMethod("sale.create", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const auto& itemsArr = p["items"].asArray();
    if (itemsArr.size() == 0) return json::fail("ERR_EMPTY_SALE");

    Sale sale;
    sale.id = ctx.ids.next(ctx.clock.now());
    sale.businessId = biz;
    sale.customerId = p["customerId"].asString();
    sale.customerName = p["customerName"].asString();
    sale.paymentMethod = domain::paymentMethodFromString(p["paymentMethod"].asString());
    sale.note = domain::sanitizeSaleNote(p["note"].asString());
    sale.source = p["source"].asString().empty() ? "direct" : p["source"].asString();
    sale.createdAt = ctx.clock.now();

    for (size_t i = 0; i < itemsArr.size(); ++i) {
      SaleItem item;
      item.productId = itemsArr[i]["productId"].asString();
      item.name = itemsArr[i]["name"].asString();
      item.quantity = itemsArr[i]["quantity"].asInt();
      item.unitPriceKurus = itemsArr[i]["unitPriceKurus"].asInt();
      if (item.quantity <= 0 || item.unitPriceKurus < 0) {
        return json::fail("ERR_INVALID_SALE_ITEM");
      }
      sale.items.push_back(item);
    }
    domain::computeSaleTotal(sale);

    ctx.store.put(coll::kSales, sale.id, sale.toJson());
    return json::ok(sale.toJson());
  });

  // ——— Satış listesi ———
  rt.registerMethod("sale.list", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    std::vector<Sale> list = salesOf(ctx.store, biz);
    std::sort(list.begin(), list.end(),
              [](const Sale& x, const Sale& y) { return x.createdAt > y.createdAt; });

    const int64_t total = static_cast<int64_t>(list.size());
    const size_t limit =
        static_cast<size_t>(p.has("limit") ? p["limit"].asInt(50) : int64_t{50});

    json::Value items = json::Value::arr();
    for (size_t i = 0; i < list.size() && i < limit; ++i) items.push(list[i].toJson());

    json::Value d = json::Value::obj();
    d.set("items", items);
    d.set("total", total);
    return json::ok(d);
  });

  // ——— Finans özeti ———
  rt.registerMethod("finance.summary", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const bool hasFrom = p.has("fromMs");
    const bool hasTo = p.has("toMs");
    const int64_t from = hasFrom ? p["fromMs"].asInt() : 0;
    const int64_t to = hasTo ? p["toMs"].asInt() : std::numeric_limits<int64_t>::max();

    int64_t totalIncome = 0;
    int64_t totalExpenses = 0;
    int64_t saleCount = 0;

    for (const Sale& s : salesOf(ctx.store, biz)) {
      if (s.createdAt < from || s.createdAt >= to) continue;
      ++saleCount;
      totalIncome += s.totalKurus;
    }

    for (const Appointment& a : appointmentsOf(ctx.store, biz)) {
      if (a.status != AppointmentStatus::Completed) continue;
      if (a.at < from || a.at >= to) continue;
      totalIncome += a.priceKurus;
    }

    json::Value d = json::Value::obj();
    d.set("totalIncome", totalIncome);
    d.set("totalExpenses", totalExpenses);
    d.set("saleCount", saleCount);
    d.set("netIncome", totalIncome - totalExpenses);
    return json::ok(d);
  });

  // ——— Reklam oluştur ———
  rt.registerMethod("ad.create", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const std::string title = domain::sanitizeAdTitle(p["title"].asString());
    if (title.empty()) return json::fail("ERR_TITLE_REQUIRED");

    const int64_t budget = p["dailyBudgetKurus"].asInt();
    if (budget <= 0) return json::fail("ERR_INVALID_BUDGET");

    Ad ad;
    ad.id = ctx.ids.next(ctx.clock.now());
    ad.businessId = biz;
    ad.title = title;
    ad.description = domain::sanitizeAdDescription(p["description"].asString());
    ad.imageUrl = p["imageUrl"].asString();
    ad.dailyBudgetKurus = budget;
    ad.bid = p["bid"].asNumber(1.0);
    ad.status = AdStatus::kActive;
    ad.createdAt = ctx.clock.now();
    ad.updatedAt = ad.createdAt;

    if (p.has("targetTopics")) {
      for (const auto& t : p["targetTopics"].asArray()) {
        ad.targetTopics.push_back(t.asString());
      }
    }

    ctx.store.put(coll::kAds, ad.id, ad.toJson());
    return json::ok(ad.toJson());
  });

  // ——— Reklam listesi ———
  rt.registerMethod("ad.list", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    std::vector<Ad> list = adsOf(ctx.store, biz);
    std::sort(list.begin(), list.end(),
              [](const Ad& x, const Ad& y) { return x.createdAt > y.createdAt; });

    json::Value items = json::Value::arr();
    for (const Ad& a : list) items.push(a.toJson());

    json::Value d = json::Value::obj();
    d.set("items", items);
    d.set("total", static_cast<int64_t>(list.size()));
    return json::ok(d);
  });

  // ——— Reklam güncelle ———
  rt.registerMethod("ad.update", [](Context& ctx, const json::Value& p) {
    const std::string biz = p["businessId"].asString();
    const std::string err = checkBusiness(ctx.store, biz);
    if (!err.empty()) return json::fail(err);

    const json::Value v = ctx.store.get(coll::kAds, p["adId"].asString());
    if (v.isNull()) return json::fail("ERR_AD_NOT_FOUND");
    Ad ad = Ad::fromJson(v);
    if (ad.businessId != biz) return json::fail("ERR_AD_NOT_FOUND");

    if (p.has("title")) {
      const std::string title = domain::sanitizeAdTitle(p["title"].asString());
      if (title.empty()) return json::fail("ERR_TITLE_REQUIRED");
      ad.title = title;
    }
    if (p.has("description")) {
      ad.description = domain::sanitizeAdDescription(p["description"].asString());
    }
    if (p.has("imageUrl")) ad.imageUrl = p["imageUrl"].asString();
    if (p.has("dailyBudgetKurus")) {
      const int64_t budget = p["dailyBudgetKurus"].asInt();
      if (budget <= 0) return json::fail("ERR_INVALID_BUDGET");
      ad.dailyBudgetKurus = budget;
    }
    if (p.has("bid")) ad.bid = p["bid"].asNumber(1.0);
    if (p.has("status")) ad.status = domain::adStatusFromString(p["status"].asString());
    ad.updatedAt = ctx.clock.now();

    ctx.store.put(coll::kAds, ad.id, ad.toJson());
    return json::ok(ad.toJson());
  });
}

}  // namespace hg::kernel
