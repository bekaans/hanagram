#include <filesystem>

#include "kernel/store.hpp"
#include "test.hpp"

using namespace hg;

TEST(store_bellek_ici_temel) {
  auto s = kernel::makeFileStore("");
  json::Value v = json::Value::obj();
  v.set("ad", "Test");
  s->put("users", "u1", v);

  CHECK(s->exists("users", "u1"));
  CHECK_EQ(s->get("users", "u1")["ad"].asString(), std::string("Test"));
  CHECK_EQ(s->count("users"), size_t(1));
  CHECK(s->remove("users", "u1"));
  CHECK(!s->exists("users", "u1"));
}

TEST(store_filtreli_sorgu) {
  auto s = kernel::makeFileStore("");
  for (int i = 0; i < 10; i++) {
    json::Value v = json::Value::obj();
    v.set("n", i);
    v.set("cift", i % 2 == 0);
    s->put("sayilar", "id" + std::to_string(i), v);
  }
  auto ciftler =
      s->where("sayilar", [](const json::Value& v) { return v["cift"].asBool(); });
  CHECK_EQ(ciftler.size(), size_t(5));
}

TEST(store_diske_yazip_geri_okur) {
  const auto dir = std::filesystem::temp_directory_path() / "hanagram_test_store";
  std::filesystem::remove_all(dir);
  {
    auto s = kernel::makeFileStore(dir.string());
    json::Value v = json::Value::obj();
    v.set("ad", "Kalıcı Kayıt");
    v.set("puan", 91);
    s->put("users", "u1", v);
    s->setSchemaVersion(1);
    s->flush();
  }
  {
    auto s = kernel::makeFileStore(dir.string());
    CHECK_EQ(s->get("users", "u1")["ad"].asString(), std::string("Kalıcı Kayıt"));
    CHECK_EQ(s->get("users", "u1")["puan"].asInt(), 91);
    CHECK_EQ(s->schemaVersion(), 1);
  }
  std::filesystem::remove_all(dir);
}

TEST(store_kimlik_sirasi_korunur) {
  auto s = kernel::makeFileStore("");
  s->put("k", "0002", json::Value::obj());
  s->put("k", "0001", json::Value::obj());
  s->put("k", "0003", json::Value::obj());
  auto all = s->all("k");
  CHECK_EQ(all.size(), size_t(3));
  CHECK_EQ(all[0].id, std::string("0001"));
  CHECK_EQ(all[2].id, std::string("0003"));
}
