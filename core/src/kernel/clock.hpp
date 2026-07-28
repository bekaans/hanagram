// Hanagram — zaman kaynağı
//
// Zaman doğrudan sistemden okunmaz; enjekte edilir. Sebep: algoritma ve iş kuralları
// (tazelik, randevu penceresi, davet süresi) zamana bağlıdır ve testte zamanın
// kontrol edilebilmesi gerekir.
#pragma once

#include <chrono>
#include <cstdint>

namespace hg::kernel {

using Millis = int64_t;

class Clock {
 public:
  virtual ~Clock() = default;
  virtual Millis now() const = 0;
};

class SystemClock final : public Clock {
 public:
  Millis now() const override {
    using namespace std::chrono;
    return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
  }
};

// Testlerde: zamanı elle ilerlet.
class FakeClock final : public Clock {
 public:
  explicit FakeClock(Millis start = 1'700'000'000'000) : t_(start) {}
  Millis now() const override { return t_; }
  void advance(Millis ms) { t_ += ms; }
  void set(Millis ms) { t_ = ms; }

 private:
  Millis t_;
};

constexpr Millis kSecond = 1000;
constexpr Millis kMinute = 60 * kSecond;
constexpr Millis kHour = 60 * kMinute;
constexpr Millis kDay = 24 * kHour;

}  // namespace hg::kernel
