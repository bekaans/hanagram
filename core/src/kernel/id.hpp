// Hanagram — sıralanabilir kimlik (ULID benzeri)
//
// Neden UUID değil: kimliklerin zamana göre sıralanabilir olması akış sorgularını
// ucuzlatır (ayrı bir zaman indeksine gerek kalmaz) ve kayıtların doğal sırası
// oluşturulma sırasıyla aynı olur.
//
// Biçim: 10 karakter zaman (48 bit, ms) + 16 karakter rastgele (80 bit),
// Crockford Base32 ile — büyük harf, karışan harfler (I, L, O, U) yok.
#pragma once

#include <cstdint>
#include <string>

namespace hg::kernel {

class IdGen {
 public:
  explicit IdGen(uint64_t seed = 0);

  // Zaman damgalı, sıralanabilir, çakışmayan kimlik.
  std::string next(int64_t nowMs);

  // Rastgele büyük harf/rakam kod — davet kodları için (okunması kolay).
  // Karışan karakterler (0/O, 1/I/L) alfabede yok.
  std::string code(int length = 8);

 private:
  uint64_t rng();
  uint64_t state_;
  int64_t lastMs_ = 0;
  uint64_t counter_ = 0;
};

// Kimlikten oluşturulma zamanını geri okur (indekssiz sıralama için).
int64_t timeFromId(const std::string& id);

}  // namespace hg::kernel
