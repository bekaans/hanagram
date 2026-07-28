#include "json.hpp"

#include <cmath>
#include <cstdio>
#include <sstream>

namespace hg::json {

const std::string Value::kEmpty;
const Array Value::kEmptyArray;
const Object Value::kEmptyObject;
const Value Value::kNull;

const Value& Value::operator[](const std::string& key) const {
  if (type_ != Type::Object) return kNull;
  auto it = obj_.find(key);
  return it == obj_.end() ? kNull : it->second;
}

bool Value::has(const std::string& key) const {
  return type_ == Type::Object && obj_.count(key) > 0;
}

Value& Value::set(const std::string& key, Value v) {
  if (type_ != Type::Object) {
    type_ = Type::Object;
    obj_.clear();
  }
  obj_[key] = std::move(v);
  return *this;
}

Value& Value::push(Value v) {
  if (type_ != Type::Array) {
    type_ = Type::Array;
    arr_.clear();
  }
  arr_.push_back(std::move(v));
  return *this;
}

// ——— Üretim ———

static void escapeTo(std::string& out, const std::string& s) {
  out += '"';
  for (unsigned char c : s) {
    switch (c) {
      case '"': out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n"; break;
      case '\r': out += "\\r"; break;
      case '\t': out += "\\t"; break;
      case '\b': out += "\\b"; break;
      case '\f': out += "\\f"; break;
      default:
        if (c < 0x20) {
          char buf[8];
          std::snprintf(buf, sizeof(buf), "\\u%04x", c);
          out += buf;
        } else {
          // UTF-8 baytları olduğu gibi geçer (Türkçe karakterler korunur)
          out += static_cast<char>(c);
        }
    }
  }
  out += '"';
}

static void numberTo(std::string& out, double n) {
  if (std::isnan(n) || std::isinf(n)) {
    out += "null";
    return;
  }
  if (n == static_cast<double>(static_cast<int64_t>(n)) && std::abs(n) < 9e15) {
    out += std::to_string(static_cast<int64_t>(n));
    return;
  }
  char buf[40];
  std::snprintf(buf, sizeof(buf), "%.10g", n);
  out += buf;
}

static void dumpTo(std::string& out, const Value& v) {
  switch (v.type()) {
    case Type::Null: out += "null"; break;
    case Type::Bool: out += v.asBool() ? "true" : "false"; break;
    case Type::Number: numberTo(out, v.asNumber()); break;
    case Type::String: escapeTo(out, v.asString()); break;
    case Type::Array: {
      out += '[';
      bool first = true;
      for (const auto& e : v.asArray()) {
        if (!first) out += ',';
        first = false;
        dumpTo(out, e);
      }
      out += ']';
      break;
    }
    case Type::Object: {
      out += '{';
      bool first = true;
      for (const auto& [k, e] : v.asObject()) {
        if (!first) out += ',';
        first = false;
        escapeTo(out, k);
        out += ':';
        dumpTo(out, e);
      }
      out += '}';
      break;
    }
  }
}

std::string Value::dump() const {
  std::string out;
  out.reserve(256);
  dumpTo(out, *this);
  return out;
}

// ——— Ayrıştırma ———

namespace {

struct Parser {
  const std::string& s;
  size_t i = 0;
  std::string err;

  explicit Parser(const std::string& src) : s(src) {}

  void skipWs() {
    while (i < s.size() && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
  }

  bool fail(const std::string& m) {
    if (err.empty()) err = m + " (konum " + std::to_string(i) + ")";
    return false;
  }

  bool parseValue(Value& out) {
    skipWs();
    if (i >= s.size()) return fail("beklenmedik son");
    switch (s[i]) {
      case '{': return parseObject(out);
      case '[': return parseArray(out);
      case '"': {
        std::string str;
        if (!parseString(str)) return false;
        out = Value(std::move(str));
        return true;
      }
      case 't':
        if (s.compare(i, 4, "true") == 0) { i += 4; out = Value(true); return true; }
        return fail("gecersiz belirtec");
      case 'f':
        if (s.compare(i, 5, "false") == 0) { i += 5; out = Value(false); return true; }
        return fail("gecersiz belirtec");
      case 'n':
        if (s.compare(i, 4, "null") == 0) { i += 4; out = Value(); return true; }
        return fail("gecersiz belirtec");
      default: return parseNumber(out);
    }
  }

  bool parseObject(Value& out) {
    i++;  // {
    Object o;
    skipWs();
    if (i < s.size() && s[i] == '}') { i++; out = Value(std::move(o)); return true; }
    while (true) {
      skipWs();
      std::string key;
      if (!parseString(key)) return false;
      skipWs();
      if (i >= s.size() || s[i] != ':') return fail("':' bekleniyordu");
      i++;
      Value v;
      if (!parseValue(v)) return false;
      o[key] = std::move(v);
      skipWs();
      if (i >= s.size()) return fail("'}' bekleniyordu");
      if (s[i] == ',') { i++; continue; }
      if (s[i] == '}') { i++; break; }
      return fail("',' veya '}' bekleniyordu");
    }
    out = Value(std::move(o));
    return true;
  }

  bool parseArray(Value& out) {
    i++;  // [
    Array a;
    skipWs();
    if (i < s.size() && s[i] == ']') { i++; out = Value(std::move(a)); return true; }
    while (true) {
      Value v;
      if (!parseValue(v)) return false;
      a.push_back(std::move(v));
      skipWs();
      if (i >= s.size()) return fail("']' bekleniyordu");
      if (s[i] == ',') { i++; continue; }
      if (s[i] == ']') { i++; break; }
      return fail("',' veya ']' bekleniyordu");
    }
    out = Value(std::move(a));
    return true;
  }

  void appendUtf8(std::string& out, unsigned int cp) {
    if (cp < 0x80) {
      out += static_cast<char>(cp);
    } else if (cp < 0x800) {
      out += static_cast<char>(0xC0 | (cp >> 6));
      out += static_cast<char>(0x80 | (cp & 0x3F));
    } else if (cp < 0x10000) {
      out += static_cast<char>(0xE0 | (cp >> 12));
      out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
      out += static_cast<char>(0x80 | (cp & 0x3F));
    } else {
      out += static_cast<char>(0xF0 | (cp >> 18));
      out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
      out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
      out += static_cast<char>(0x80 | (cp & 0x3F));
    }
  }

  bool hex4(unsigned int& v) {
    if (i + 4 > s.size()) return fail("eksik \\u kacisi");
    v = 0;
    for (int k = 0; k < 4; k++) {
      char c = s[i + k];
      v <<= 4;
      if (c >= '0' && c <= '9') v |= static_cast<unsigned>(c - '0');
      else if (c >= 'a' && c <= 'f') v |= static_cast<unsigned>(c - 'a' + 10);
      else if (c >= 'A' && c <= 'F') v |= static_cast<unsigned>(c - 'A' + 10);
      else return fail("gecersiz onaltilik");
    }
    i += 4;
    return true;
  }

  bool parseString(std::string& out) {
    skipWs();
    if (i >= s.size() || s[i] != '"') return fail("'\"' bekleniyordu");
    i++;
    out.clear();
    while (i < s.size()) {
      char c = s[i];
      if (c == '"') { i++; return true; }
      if (c == '\\') {
        i++;
        if (i >= s.size()) return fail("eksik kacis");
        char e = s[i++];
        switch (e) {
          case '"': out += '"'; break;
          case '\\': out += '\\'; break;
          case '/': out += '/'; break;
          case 'n': out += '\n'; break;
          case 'r': out += '\r'; break;
          case 't': out += '\t'; break;
          case 'b': out += '\b'; break;
          case 'f': out += '\f'; break;
          case 'u': {
            unsigned int cp = 0;
            if (!hex4(cp)) return false;
            // Vekil çift (surrogate pair)
            if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < s.size() && s[i] == '\\' && s[i + 1] == 'u') {
              i += 2;
              unsigned int lo = 0;
              if (!hex4(lo)) return false;
              if (lo >= 0xDC00 && lo <= 0xDFFF) {
                cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
              }
            }
            appendUtf8(out, cp);
            break;
          }
          default: return fail("bilinmeyen kacis");
        }
        continue;
      }
      out += c;
      i++;
    }
    return fail("kapanmamis dize");
  }

  bool parseNumber(Value& out) {
    size_t start = i;
    if (i < s.size() && (s[i] == '-' || s[i] == '+')) i++;
    bool any = false;
    while (i < s.size() && s[i] >= '0' && s[i] <= '9') { i++; any = true; }
    if (i < s.size() && s[i] == '.') {
      i++;
      while (i < s.size() && s[i] >= '0' && s[i] <= '9') { i++; any = true; }
    }
    if (any && i < s.size() && (s[i] == 'e' || s[i] == 'E')) {
      i++;
      if (i < s.size() && (s[i] == '-' || s[i] == '+')) i++;
      while (i < s.size() && s[i] >= '0' && s[i] <= '9') i++;
    }
    if (!any) return fail("sayi bekleniyordu");
    out = Value(std::stod(s.substr(start, i - start)));
    return true;
  }
};

}  // namespace

Value parse(const std::string& text, std::string* error) {
  Parser p(text);
  Value v;
  if (!p.parseValue(v)) {
    if (error) *error = p.err;
    return Value();
  }
  p.skipWs();
  if (p.i != text.size()) {
    if (error) *error = "sondaki fazlalik veri";
    return Value();
  }
  if (error) error->clear();
  return v;
}

Value ok(Value payload) {
  Value v = Value::obj();
  v.set("ok", true);
  v.set("data", std::move(payload));
  return v;
}

Value fail(const std::string& code, const std::string& hint) {
  Value v = Value::obj();
  v.set("ok", false);
  v.set("code", code);
  if (!hint.empty()) v.set("hint", hint);
  return v;
}

}  // namespace hg::json
