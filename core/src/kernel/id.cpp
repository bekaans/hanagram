#include "id.hpp"

#include <chrono>
#include <random>

namespace hg::kernel {

namespace {
// Crockford Base32 — I, L, O, U yok (okuma/yazma hatalarını önler).
constexpr char kAlphabet[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
constexpr int kAlphabetSize = 32;

// Davet kodu alfabesi: rakam+harf, ama 0/O ve 1/I/L çiftleri ayıklanmış.
constexpr char kCodeAlphabet[] = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
constexpr int kCodeAlphabetSize = 31;
}  // namespace

IdGen::IdGen(uint64_t seed) {
  if (seed == 0) {
    std::random_device rd;
    seed = (static_cast<uint64_t>(rd()) << 32) ^ rd() ^
           static_cast<uint64_t>(
               std::chrono::steady_clock::now().time_since_epoch().count());
  }
  state_ = seed ? seed : 0x9E3779B97F4A7C15ULL;
}

// splitmix64 — küçük, hızlı, iyi dağılımlı. Kriptografik değil (kimlik için gerekmiyor).
uint64_t IdGen::rng() {
  state_ += 0x9E3779B97F4A7C15ULL;
  uint64_t z = state_;
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
  return z ^ (z >> 31);
}

std::string IdGen::next(int64_t nowMs) {
  // Aynı milisaniyede üretilen kimlikler de artan sırada kalmalı.
  if (nowMs == lastMs_) {
    counter_++;
  } else {
    lastMs_ = nowMs;
    counter_ = 0;
  }

  std::string out(26, '0');
  uint64_t t = static_cast<uint64_t>(nowMs);
  for (int i = 9; i >= 0; i--) {
    out[i] = kAlphabet[t % kAlphabetSize];
    t /= kAlphabetSize;
  }
  // Aynı milisaniye içinde üretilen kimlikler de ARTAN sırada olmalı: sayaç
  // rastgele bölümün en anlamlı basamaklarına yazılır. Rastgeleyle XOR'lansaydı
  // sıra bozulurdu — kimliğe göre sıralamanın zaman sırası vermesi buna bağlı.
  uint64_t c = counter_;
  for (int i = 12; i >= 10; i--) {
    out[i] = kAlphabet[c % kAlphabetSize];
    c /= kAlphabetSize;
  }
  uint64_t r = rng();
  for (int i = 25; i >= 13; i--) {
    out[i] = kAlphabet[r % kAlphabetSize];
    r = (r / kAlphabetSize) ^ (r >> 17);
    if (r == 0) r = rng();
  }
  return out;
}

std::string IdGen::code(int length) {
  if (length < 4) length = 4;
  if (length > 32) length = 32;
  std::string out(static_cast<size_t>(length), '0');
  for (int i = 0; i < length; i++) {
    out[static_cast<size_t>(i)] = kCodeAlphabet[rng() % kCodeAlphabetSize];
  }
  return out;
}

int64_t timeFromId(const std::string& id) {
  if (id.size() < 10) return 0;
  int64_t t = 0;
  for (int i = 0; i < 10; i++) {
    const char* p = nullptr;
    for (int k = 0; k < kAlphabetSize; k++) {
      if (kAlphabet[k] == id[static_cast<size_t>(i)]) {
        p = kAlphabet + k;
        break;
      }
    }
    if (!p) return 0;
    t = t * kAlphabetSize + (p - kAlphabet);
  }
  return t;
}

}  // namespace hg::kernel
