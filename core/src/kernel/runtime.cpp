#include "runtime.hpp"

namespace hg::kernel {

Runtime::Runtime(const std::string& dataDir, std::unique_ptr<Clock> clock)
    : store_(makeFileStore(dataDir)),
      clock_(clock ? std::move(clock) : std::unique_ptr<Clock>(new SystemClock())) {
  migrate();
  loadWeights();

  // Öğrenme penceresini geri yükle — uygulama kapanıp açılınca öğrenilen kaybolmasın.
  json::Value saved = store_->get(coll::kSystem, "learner");
  if (!saved.isNull()) learner_.loadJson(saved);

  registerBuiltins();
  registerIdentityApi(*this);
  registerSocialApi(*this);
  registerAdminApi(*this);
  registerMessagingApi(*this);
  registerBusinessApi(*this);
  registerMediaApi(*this);
}

Runtime::~Runtime() {
  // Öğrenilen bilgi ve veri diske yazılır.
  store_->put(coll::kSystem, "learner", learner_.toJson());
  persistWeights();
  store_->flush();
}

void Runtime::migrate() {
  const int current = store_->schemaVersion();
  if (current == kSchemaVersion) return;
  // v0 → v1: ilk kurulum, taşınacak veri yok.
  store_->setSchemaVersion(kSchemaVersion);
}

void Runtime::loadWeights() {
  json::Value w = store_->get(coll::kSystem, "weights");
  if (!w.isNull()) ranker_.setWeights(algo::Weights::fromJson(w));
}

void Runtime::persistWeights() {
  store_->put(coll::kSystem, "weights", ranker_.weights().toJson());
}

void Runtime::registerMethod(const std::string& name, MethodHandler h) {
  std::lock_guard<std::mutex> lock(mu_);
  methods_[name] = std::move(h);
}

std::vector<std::string> Runtime::methods() const {
  std::lock_guard<std::mutex> lock(mu_);
  std::vector<std::string> out;
  out.reserve(methods_.size());
  for (const auto& [k, _] : methods_) out.push_back(k);
  return out;
}

std::string Runtime::call(const std::string& method, const std::string& payloadJson) {
  std::string parseErr;
  json::Value payload = payloadJson.empty()
                            ? json::Value::obj()
                            : json::parse(payloadJson, &parseErr);
  if (!parseErr.empty()) {
    return json::fail("ERR_BAD_PAYLOAD", parseErr).dump();
  }

  MethodHandler h;
  {
    std::lock_guard<std::mutex> lock(mu_);
    auto it = methods_.find(method);
    if (it == methods_.end()) {
      return json::fail("ERR_UNKNOWN_METHOD", method).dump();
    }
    h = it->second;
  }

  Context ctx{*store_, bus_, *clock_, ids_, ranker_, learner_, *this};
  try {
    return h(ctx, payload).dump();
  } catch (const std::exception& e) {
    // Çekirdek dışarıya istisna sızdırmaz — sözleşme her zaman sonuç JSON'udur.
    return json::fail("ERR_INTERNAL", e.what()).dump();
  } catch (...) {
    return json::fail("ERR_INTERNAL", "bilinmeyen").dump();
  }
}

json::Value Runtime::tick() {
  const int64_t now = clock_->now();
  lastTick_ = now;

  json::Value result = json::Value::obj();

  // Öğrenme kalibrasyonu — yeterli veri varsa.
  if (learner_.ready()) {
    algo::Calibration cal = learner_.calibrate(ranker_.weights(), now);
    if (cal.applied) {
      ranker_.setWeights(cal.after);
      persistWeights();
      bus_.emit(topics::kWeightsCalibrated, cal.toJson());
    }
    // Uygulansın ya da uygulanmasın kaydedilir — admin geçmişi görür.
    store_->put(coll::kCalibrations, ids_.next(now), cal.toJson());
    result.set("calibration", cal.toJson());
  }

  store_->put(coll::kSystem, "learner", learner_.toJson());
  store_->flush();

  result.set("at", now);
  return json::ok(result);
}

void Runtime::registerBuiltins() {
  registerMethod("system.ping", [](Context& ctx, const json::Value&) {
    json::Value v = json::Value::obj();
    v.set("pong", true);
    v.set("now", ctx.clock.now());
    return json::ok(v);
  });

  registerMethod("system.methods", [](Context& ctx, const json::Value&) {
    json::Value arr = json::Value::arr();
    for (const auto& m : ctx.rt.methods()) arr.push(m);
    json::Value v = json::Value::obj();
    v.set("methods", arr);
    return json::ok(v);
  });

  registerMethod("system.tick", [](Context& ctx, const json::Value&) {
    return ctx.rt.tick();
  });

  registerMethod("system.flush", [](Context& ctx, const json::Value&) {
    ctx.rt.flush();
    return json::ok(json::Value::obj());
  });
}

}  // namespace hg::kernel
