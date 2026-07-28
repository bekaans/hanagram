#include "store.hpp"

#include <filesystem>
#include <fstream>
#include <map>
#include <mutex>
#include <sstream>

namespace hg::kernel {

namespace {

namespace fs = std::filesystem;

class FileStore final : public Store {
 public:
  explicit FileStore(std::string dir) : dir_(std::move(dir)) {
    if (!dir_.empty()) {
      std::error_code ec;
      fs::create_directories(dir_, ec);
      load();
    }
  }

  ~FileStore() override {
    if (dirty_) flush();
  }

  void put(const std::string& c, const std::string& id, const json::Value& data) override {
    std::lock_guard<std::mutex> lock(mu_);
    db_[c][id] = data;
    dirty_ = true;
  }

  json::Value get(const std::string& c, const std::string& id) const override {
    std::lock_guard<std::mutex> lock(mu_);
    auto ci = db_.find(c);
    if (ci == db_.end()) return json::Value();
    auto ri = ci->second.find(id);
    return ri == ci->second.end() ? json::Value() : ri->second;
  }

  bool remove(const std::string& c, const std::string& id) override {
    std::lock_guard<std::mutex> lock(mu_);
    auto ci = db_.find(c);
    if (ci == db_.end()) return false;
    bool erased = ci->second.erase(id) > 0;
    if (erased) dirty_ = true;
    return erased;
  }

  bool exists(const std::string& c, const std::string& id) const override {
    std::lock_guard<std::mutex> lock(mu_);
    auto ci = db_.find(c);
    return ci != db_.end() && ci->second.count(id) > 0;
  }

  std::vector<Record> all(const std::string& c) const override {
    std::lock_guard<std::mutex> lock(mu_);
    std::vector<Record> out;
    auto ci = db_.find(c);
    if (ci == db_.end()) return out;
    out.reserve(ci->second.size());
    // std::map kimliğe göre sıralı tutar; kimlikler zaman öncelikli olduğu için
    // sonuç doğal olarak oluşturulma sırasındadır.
    for (const auto& [id, v] : ci->second) out.push_back({id, v});
    return out;
  }

  std::vector<Record> where(const std::string& c, const Predicate& pred) const override {
    std::lock_guard<std::mutex> lock(mu_);
    std::vector<Record> out;
    auto ci = db_.find(c);
    if (ci == db_.end()) return out;
    for (const auto& [id, v] : ci->second) {
      if (pred(v)) out.push_back({id, v});
    }
    return out;
  }

  size_t count(const std::string& c) const override {
    std::lock_guard<std::mutex> lock(mu_);
    auto ci = db_.find(c);
    return ci == db_.end() ? 0 : ci->second.size();
  }

  std::vector<std::string> collections() const override {
    std::lock_guard<std::mutex> lock(mu_);
    std::vector<std::string> out;
    out.reserve(db_.size());
    for (const auto& [name, _] : db_) out.push_back(name);
    return out;
  }

  void flush() override {
    std::lock_guard<std::mutex> lock(mu_);
    if (dir_.empty()) {
      dirty_ = false;
      return;
    }
    for (const auto& [name, records] : db_) {
      json::Value root = json::Value::obj();
      for (const auto& [id, v] : records) root.set(id, v);

      // Atomik yazım: önce geçici dosya, sonra yer değiştirme. Yazma sırasında
      // uygulama kapanırsa mevcut veri bozulmaz.
      const fs::path target = fs::path(dir_) / (name + ".json");
      const fs::path tmp = fs::path(dir_) / (name + ".json.tmp");
      {
        std::ofstream f(tmp, std::ios::binary | std::ios::trunc);
        if (!f) continue;
        f << root.dump();
      }
      std::error_code ec;
      fs::rename(tmp, target, ec);
      if (ec) fs::remove(tmp, ec);
    }
    {
      json::Value meta = json::Value::obj();
      meta.set("schemaVersion", schema_);
      std::ofstream f(fs::path(dir_) / "_meta.json", std::ios::binary | std::ios::trunc);
      if (f) f << meta.dump();
    }
    dirty_ = false;
  }

  int schemaVersion() const override {
    std::lock_guard<std::mutex> lock(mu_);
    return schema_;
  }

  void setSchemaVersion(int v) override {
    std::lock_guard<std::mutex> lock(mu_);
    schema_ = v;
    dirty_ = true;
  }

 private:
  void load() {
    std::error_code ec;
    if (!fs::exists(dir_, ec)) return;
    for (const auto& entry : fs::directory_iterator(dir_, ec)) {
      if (ec) break;
      if (!entry.is_regular_file()) continue;
      const auto path = entry.path();
      if (path.extension() != ".json") continue;

      std::ifstream f(path, std::ios::binary);
      if (!f) continue;
      std::stringstream ss;
      ss << f.rdbuf();
      std::string err;
      json::Value root = json::parse(ss.str(), &err);
      if (!err.empty() || !root.isObject()) continue;

      const std::string name = path.stem().string();
      if (name == "_meta") {
        schema_ = static_cast<int>(root["schemaVersion"].asInt(0));
        continue;
      }
      auto& coll = db_[name];
      for (const auto& [id, v] : root.asObject()) coll[id] = v;
    }
  }

  mutable std::mutex mu_;
  std::string dir_;
  std::map<std::string, std::map<std::string, json::Value>> db_;
  int schema_ = 0;
  bool dirty_ = false;
};

}  // namespace

std::unique_ptr<Store> makeFileStore(const std::string& dataDir) {
  return std::make_unique<FileStore>(dataDir);
}

}  // namespace hg::kernel
