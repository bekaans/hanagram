// Hanagram — olay veriyolu
//
// Modüller birbirini doğrudan çağırmaz; olay yayınlar. Böylece bir modülü çıkarmak
// diğerlerini kırmaz (docs/01-mimari.md §3). Ayrıca çekirdek → uygulama bildirimleri
// (yeni içerik, iş tamamlandı) aynı yoldan gider.
#pragma once

#include <functional>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

#include "../util/json.hpp"

namespace hg::kernel {

using Subscription = uint64_t;
using Handler = std::function<void(const std::string& topic, const json::Value& payload)>;

class EventBus {
 public:
  // Belirli bir konuya abone ol. topic "*" ise tüm olaylar.
  Subscription on(const std::string& topic, Handler h) {
    std::lock_guard<std::mutex> lock(mu_);
    Subscription id = ++nextId_;
    subs_[topic].push_back({id, std::move(h)});
    return id;
  }

  void off(Subscription id) {
    std::lock_guard<std::mutex> lock(mu_);
    for (auto& [topic, list] : subs_) {
      for (size_t i = 0; i < list.size(); i++) {
        if (list[i].id == id) {
          list.erase(list.begin() + static_cast<long>(i));
          return;
        }
      }
    }
  }

  void emit(const std::string& topic, const json::Value& payload) {
    // Kopya alıp kilidi bırakıyoruz: bir işleyici emit çağırırsa kilitlenme olmasın.
    std::vector<Handler> toCall;
    {
      std::lock_guard<std::mutex> lock(mu_);
      auto it = subs_.find(topic);
      if (it != subs_.end()) {
        for (const auto& s : it->second) toCall.push_back(s.fn);
      }
      auto wild = subs_.find("*");
      if (wild != subs_.end()) {
        for (const auto& s : wild->second) toCall.push_back(s.fn);
      }
    }
    for (const auto& h : toCall) h(topic, payload);
  }

 private:
  struct Sub {
    Subscription id;
    Handler fn;
  };
  mutable std::mutex mu_;
  std::unordered_map<std::string, std::vector<Sub>> subs_;
  Subscription nextId_ = 0;
};

// Olay adları — tek yerde, yazım hatası olmasın.
namespace topics {
constexpr const char* kUserJoined = "user.joined";
constexpr const char* kPostCreated = "post.created";
constexpr const char* kSignalRecorded = "signal.recorded";
constexpr const char* kProfileUpdated = "profile.updated";
constexpr const char* kWeightsCalibrated = "algo.weights_calibrated";
constexpr const char* kAppointmentRequested = "appointment.requested";
constexpr const char* kInviteRedeemed = "invite.redeemed";
}  // namespace topics

}  // namespace hg::kernel
