// Hanagram — çekirdek çalışma zamanı
//
// "Sistemi ayakta tutan" katman: yaşam döngüsü, depo, olay veriyolu, zaman, kimlik
// üretimi ve metot yönlendirme. İş kuralı burada DEĞİL — domain/ ve algo/ içinde.
//
// Dış dünyaya tek kapı: call(method, payloadJson) → sonuç JSON.
#pragma once

#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>

#include "../algo/learner.hpp"
#include "../algo/ranker.hpp"
#include "../util/json.hpp"
#include "clock.hpp"
#include "eventbus.hpp"
#include "id.hpp"
#include "store.hpp"

namespace hg::kernel {

class Runtime;

// Handler'lara geçen bağlam. Handler'lar Runtime'ın iç yapısını değil bunu görür.
struct Context {
  Store& store;
  EventBus& bus;
  Clock& clock;
  IdGen& ids;
  algo::Ranker& ranker;
  algo::Learner& learner;
  Runtime& rt;
};

using MethodHandler = std::function<json::Value(Context&, const json::Value&)>;

class Runtime {
 public:
  // dataDir boşsa bellek içi çalışır (testler).
  explicit Runtime(const std::string& dataDir, std::unique_ptr<Clock> clock = nullptr);
  ~Runtime();

  // Tek giriş noktası. Bilinmeyen metot ERR_UNKNOWN_METHOD döner.
  std::string call(const std::string& method, const std::string& payloadJson);

  // Olay akışı: çekirdek → uygulama.
  Subscription subscribe(Handler h) { return bus_.on("*", std::move(h)); }
  void unsubscribe(Subscription s) { bus_.off(s); }

  void registerMethod(const std::string& name, MethodHandler h);
  std::vector<std::string> methods() const;

  // Bakım işleri: öğrenme kalibrasyonu, temizlik. Uygulama uygun anda çağırır
  // (arka plan / uygulama arkaplana geçerken).
  json::Value tick();

  void flush() { store_->flush(); }

  Store& store() { return *store_; }
  Clock& clock() { return *clock_; }
  IdGen& ids() { return ids_; }
  algo::Ranker& ranker() { return ranker_; }
  algo::Learner& learner() { return learner_; }
  EventBus& bus() { return bus_; }

  // Ağırlıkları yükle/kaydet (kalibrasyon sonrası kalıcı olur).
  void persistWeights();
  void loadWeights();

 private:
  void registerBuiltins();
  void migrate();

  std::unique_ptr<Store> store_;
  std::unique_ptr<Clock> clock_;
  EventBus bus_;
  IdGen ids_;
  algo::Ranker ranker_;
  algo::Learner learner_;
  std::map<std::string, MethodHandler> methods_;
  mutable std::mutex mu_;
  int64_t lastTick_ = 0;
};

// Koleksiyon adları — tek yerde.
namespace coll {
constexpr const char* kUsers = "users";
constexpr const char* kInvites = "invites";
constexpr const char* kPosts = "posts";
constexpr const char* kSignals = "signals";
constexpr const char* kProfiles = "interest_profiles";
constexpr const char* kMessages = "messages";
constexpr const char* kThreads = "threads";
constexpr const char* kAppointments = "appointments";
constexpr const char* kCustomers = "customers";
constexpr const char* kBusinessHours = "business_hours";
constexpr const char* kAds = "ads";
constexpr const char* kProducts = "products";
constexpr const char* kSales = "sales";
constexpr const char* kMedia = "media";
constexpr const char* kSystem = "system";
constexpr const char* kCalibrations = "calibrations";
}  // namespace coll

// Handler kayıt fonksiyonları (api/*.cpp içinde tanımlı).
void registerIdentityApi(Runtime& rt);
void registerSocialApi(Runtime& rt);
void registerAdminApi(Runtime& rt);
void registerMessagingApi(Runtime& rt);
void registerBusinessApi(Runtime& rt);
void registerMediaApi(Runtime& rt);

constexpr int kSchemaVersion = 1;

}  // namespace hg::kernel
