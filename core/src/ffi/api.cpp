// Hanagram — C ABI uygulaması
//
// Bu dosya ince bir yapıştırıcıdır: iş mantığı içermez, yalnızca C dünyası ile
// C++ çalışma zamanı arasında çeviri yapar. Buraya kural yazılmaz.
#include <cstring>
#include <new>
#include <string>

#include "hanagram/hanagram.h"
#include "../kernel/runtime.hpp"

namespace {

struct RuntimeHandle {
  hg::kernel::Runtime rt;
  explicit RuntimeHandle(const std::string& dir) : rt(dir) {}
};

char* dup(const std::string& s) {
  char* out = static_cast<char*>(std::malloc(s.size() + 1));
  if (!out) return nullptr;
  std::memcpy(out, s.c_str(), s.size() + 1);
  return out;
}

// Hata durumunda bile geçerli bir JSON dönmeliyiz — sözleşme bu.
char* dupOrFallback(const std::string& s) {
  char* p = dup(s);
  if (p) return p;
  static char kOom[] = "{\"ok\":false,\"code\":\"ERR_OOM\"}";
  return kOom;
}

}  // namespace

extern "C" {

hg_runtime* hg_start(const char* data_dir, const char* config_json) {
  (void)config_json;  // v1: yapılandırma kullanılmıyor, sözleşme ileriye dönük
  try {
    const std::string dir = data_dir ? data_dir : "";
    auto* h = new RuntimeHandle(dir);
    return reinterpret_cast<hg_runtime*>(h);
  } catch (...) {
    return nullptr;
  }
}

void hg_stop(hg_runtime* rt) {
  if (!rt) return;
  delete reinterpret_cast<RuntimeHandle*>(rt);
}

char* hg_call(hg_runtime* rt, const char* method, const char* payload_json) {
  if (!rt || !method) {
    return dupOrFallback("{\"ok\":false,\"code\":\"ERR_NOT_STARTED\"}");
  }
  auto* h = reinterpret_cast<RuntimeHandle*>(rt);
  try {
    const std::string result = h->rt.call(method, payload_json ? payload_json : "");
    return dupOrFallback(result);
  } catch (...) {
    return dupOrFallback("{\"ok\":false,\"code\":\"ERR_INTERNAL\"}");
  }
}

uint64_t hg_subscribe(hg_runtime* rt, hg_event_cb cb, void* user_data) {
  if (!rt || !cb) return 0;
  auto* h = reinterpret_cast<RuntimeHandle*>(rt);
  return h->rt.subscribe(
      [cb, user_data](const std::string& topic, const hg::json::Value& payload) {
        const std::string body = payload.dump();
        cb(topic.c_str(), body.c_str(), user_data);
      });
}

void hg_unsubscribe(hg_runtime* rt, uint64_t subscription) {
  if (!rt || subscription == 0) return;
  auto* h = reinterpret_cast<RuntimeHandle*>(rt);
  h->rt.unsubscribe(subscription);
}

void hg_free(char* s) {
  if (s) std::free(s);
}

const char* hg_version(void) { return "1.0.0"; }
int hg_abi_major(void) { return HANAGRAM_ABI_MAJOR; }
int hg_abi_minor(void) { return HANAGRAM_ABI_MINOR; }

}  // extern "C"
