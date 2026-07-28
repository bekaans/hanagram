#include "test.hpp"
#include "util/json.hpp"

using namespace hg;

TEST(json_roundtrip_nesne) {
  json::Value v = json::Value::obj();
  v.set("ad", "Kaan");
  v.set("sayi", 42);
  v.set("acik", true);

  const std::string s = v.dump();
  std::string err;
  json::Value back = json::parse(s, &err);

  CHECK(err.empty());
  CHECK_EQ(back["ad"].asString(), std::string("Kaan"));
  CHECK_EQ(back["sayi"].asInt(), 42);
  CHECK(back["acik"].asBool());
}

TEST(json_turkce_karakterler_korunur) {
  json::Value v = json::Value::obj();
  v.set("metin", "Güzellik Merkezi · İstanbul şığ ÖĞÜ");
  std::string err;
  json::Value back = json::parse(v.dump(), &err);
  CHECK(err.empty());
  CHECK_EQ(back["metin"].asString(), std::string("Güzellik Merkezi · İstanbul şığ ÖĞÜ"));
}

TEST(json_dizi_ve_ic_ice) {
  std::string err;
  json::Value v = json::parse(R"({"a":[1,2,{"b":"c"}],"d":null})", &err);
  CHECK(err.empty());
  CHECK_EQ(v["a"].asArray().size(), size_t(3));
  CHECK_EQ(v["a"].asArray()[2]["b"].asString(), std::string("c"));
  CHECK(v["d"].isNull());
}

TEST(json_bozuk_girdi_hata_verir) {
  std::string err;
  json::Value v = json::parse("{\"a\":", &err);
  CHECK(!err.empty());
  CHECK(v.isNull());
}

TEST(json_eksik_alan_guvenli) {
  json::Value v = json::Value::obj();
  // Olmayan alana zincirleme erişim çökmemeli
  CHECK_EQ(v["yok"]["daha_yok"].asString(), std::string(""));
  CHECK_EQ(v["yok"].asInt(7), int64_t(7));
}

TEST(json_kacis_karakterleri) {
  json::Value v = json::Value::obj();
  v.set("t", "satir\nson\t\"tirnak\"");
  std::string err;
  json::Value back = json::parse(v.dump(), &err);
  CHECK(err.empty());
  CHECK_EQ(back["t"].asString(), std::string("satir\nson\t\"tirnak\""));
}

TEST(json_sonuc_sozlesmesi) {
  json::Value okv = json::ok(json::Value::obj());
  CHECK(okv["ok"].asBool());

  json::Value err = json::fail("ERR_TEST", "ipucu");
  CHECK(!err["ok"].asBool());
  CHECK_EQ(err["code"].asString(), std::string("ERR_TEST"));
  CHECK_EQ(err["hint"].asString(), std::string("ipucu"));
}
