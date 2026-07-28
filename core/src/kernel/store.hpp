// Hanagram — kalıcı depo
//
// Depo bir ARAYÜZDÜR. v1'de dosya tabanlı uygulama kullanılır (sıfır bağımlılık);
// v1.1'de SQLite adaptörü aynı arayüzü uygular ve üst katmanların hiçbiri değişmez.
// Bu, mimarinin "değiştirilebilir altyapı" taahhüdünün somut karşılığıdır.
#pragma once

#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "../util/json.hpp"

namespace hg::kernel {

// Bir kayıt: koleksiyon içinde kimlikle adreslenen JSON nesnesi.
struct Record {
  std::string id;
  json::Value data;
};

using Predicate = std::function<bool(const json::Value&)>;

class Store {
 public:
  virtual ~Store() = default;

  virtual void put(const std::string& collection, const std::string& id,
                   const json::Value& data) = 0;
  virtual json::Value get(const std::string& collection, const std::string& id) const = 0;
  virtual bool remove(const std::string& collection, const std::string& id) = 0;
  virtual bool exists(const std::string& collection, const std::string& id) const = 0;

  // Tüm kayıtlar (kimliğe göre artan = oluşturulma sırası; bkz. id.hpp).
  virtual std::vector<Record> all(const std::string& collection) const = 0;

  // Filtreli sorgu. Karmaşık sorgu ihtiyacı doğarsa SQLite adaptörü indeks kullanır.
  virtual std::vector<Record> where(const std::string& collection,
                                    const Predicate& pred) const = 0;

  virtual size_t count(const std::string& collection) const = 0;
  virtual std::vector<std::string> collections() const = 0;

  // Diske yaz. Çağrılmazsa kapanışta otomatik yazılır.
  virtual void flush() = 0;

  // Şema sürümü — göç (migration) için.
  virtual int schemaVersion() const = 0;
  virtual void setSchemaVersion(int v) = 0;
};

// Dosya tabanlı depo: veriyi bellekte tutar, değişiklikte diske yazar.
// dataDir boşsa yalnızca bellekte çalışır (testler için).
std::unique_ptr<Store> makeFileStore(const std::string& dataDir);

}  // namespace hg::kernel
