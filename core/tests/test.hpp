// Hanagram — minimal test çerçevesi (bağımlılık yok)
#pragma once

#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace hgtest {

struct Case {
  std::string name;
  void (*fn)();
};

inline std::vector<Case>& registry() {
  static std::vector<Case> r;
  return r;
}

inline int& failures() {
  static int f = 0;
  return f;
}

inline std::string& currentTest() {
  static std::string s;
  return s;
}

struct Registrar {
  Registrar(const std::string& name, void (*fn)()) { registry().push_back({name, fn}); }
};

inline void report(const std::string& what, const char* file, int line) {
  failures()++;
  std::cout << "  ✗ " << currentTest() << "\n    " << what << "\n    " << file << ":"
            << line << "\n";
}

inline void checkTrue(bool cond, const std::string& expr, const char* file, int line) {
  if (!cond) report("beklenen dogru: " + expr, file, line);
}

template <typename A, typename B>
void checkEq(const A& a, const B& b, const std::string& expr, const char* file, int line) {
  if (!(a == b)) {
    std::cout.flush();
    report("esitlik basarisiz: " + expr, file, line);
  }
}

inline void checkNear(double a, double b, double eps, const std::string& expr,
                      const char* file, int line) {
  if (std::fabs(a - b) > eps) {
    report("yaklasik esit degil: " + expr + " (" + std::to_string(a) + " vs " +
               std::to_string(b) + ")",
           file, line);
  }
}

inline int run() {
  std::cout << "\nHanagram cekirdek testleri — " << registry().size() << " senaryo\n\n";
  for (const auto& c : registry()) {
    currentTest() = c.name;
    const int before = failures();
    c.fn();
    if (failures() == before) std::cout << "  ✓ " << c.name << "\n";
  }
  std::cout << "\n";
  if (failures() == 0) {
    std::cout << "TUMU GECTI (" << registry().size() << " senaryo)\n\n";
    return 0;
  }
  std::cout << failures() << " HATA\n\n";
  return 1;
}

}  // namespace hgtest

#define TEST(name)                                                    \
  static void name();                                                 \
  static hgtest::Registrar reg_##name(#name, name);                   \
  static void name()

#define CHECK(cond) hgtest::checkTrue((cond), #cond, __FILE__, __LINE__)
#define CHECK_EQ(a, b) hgtest::checkEq((a), (b), #a " == " #b, __FILE__, __LINE__)
#define CHECK_NEAR(a, b, eps) \
  hgtest::checkNear((a), (b), (eps), #a " ~= " #b, __FILE__, __LINE__)
