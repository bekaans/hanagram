// Hanagram — minimal JSON (bağımlılık yok)
//
// Neden kendi JSON'umuz: çekirdeğin sıfır üçüncü-taraf bağımlılığı olması bir mimari
// karar (bkz. docs/01-mimari.md §4). İhtiyacımız olan yüzey dar: ayrıştır, üret,
// tip güvenli oku. Tam RFC 8259 uyumu hedeflenmiyor; kabul edilen alt küme:
// nesne, dizi, dize (\u kaçışları dahil), sayı (double), true/false/null.
#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace hg::json {

class Value;
using Object = std::map<std::string, Value>;
using Array = std::vector<Value>;

enum class Type { Null, Bool, Number, String, Array, Object };

class Value {
 public:
  Value() : type_(Type::Null) {}
  Value(std::nullptr_t) : type_(Type::Null) {}
  Value(bool b) : type_(Type::Bool), bool_(b) {}
  Value(double n) : type_(Type::Number), num_(n) {}
  Value(int n) : type_(Type::Number), num_(static_cast<double>(n)) {}
  Value(int64_t n) : type_(Type::Number), num_(static_cast<double>(n)) {}
  Value(const char* s) : type_(Type::String), str_(s) {}
  Value(std::string s) : type_(Type::String), str_(std::move(s)) {}
  Value(Array a) : type_(Type::Array), arr_(std::move(a)) {}
  Value(Object o) : type_(Type::Object), obj_(std::move(o)) {}

  Type type() const { return type_; }
  bool isNull() const { return type_ == Type::Null; }
  bool isObject() const { return type_ == Type::Object; }
  bool isArray() const { return type_ == Type::Array; }

  // Tip güvenli okuma — yanlış tipte varsayılan döner, asla fırlatmaz.
  bool asBool(bool def = false) const { return type_ == Type::Bool ? bool_ : def; }
  double asNumber(double def = 0) const { return type_ == Type::Number ? num_ : def; }
  int64_t asInt(int64_t def = 0) const {
    return type_ == Type::Number ? static_cast<int64_t>(num_) : def;
  }
  const std::string& asString(const std::string& def = kEmpty) const {
    return type_ == Type::String ? str_ : def;
  }
  const Array& asArray() const { return type_ == Type::Array ? arr_ : kEmptyArray; }
  const Object& asObject() const { return type_ == Type::Object ? obj_ : kEmptyObject; }

  // Nesne alanına erişim; yoksa null Value döner (zincirleme güvenli).
  const Value& operator[](const std::string& key) const;
  bool has(const std::string& key) const;

  // Yazma
  Value& set(const std::string& key, Value v);
  Value& push(Value v);

  std::string dump() const;

  static Value obj() { return Value(Object{}); }
  static Value arr() { return Value(Array{}); }

 private:
  Type type_;
  bool bool_ = false;
  double num_ = 0;
  std::string str_;
  Array arr_;
  Object obj_;

  static const std::string kEmpty;
  static const Array kEmptyArray;
  static const Object kEmptyObject;
  static const Value kNull;
};

// Ayrıştırma. Başarısızlıkta Null döner ve `error` doldurulur.
Value parse(const std::string& text, std::string* error = nullptr);

// Yardımcılar — sonuç sözleşmesi (docs/01-mimari.md §12)
Value ok(Value payload);
Value fail(const std::string& code, const std::string& hint = "");

}  // namespace hg::json
