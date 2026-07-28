// Uçtan uca API testleri — C ABI'nin arkasındaki gerçek akışlar.
//
// Not: davet kodları O, I, L harflerini İÇERMEZ. Kod alfabesi bu harfleri dışlar
// (kernel/id.cpp) ve normalizeCode bunları rakama çevirir; testteki kodlar da bu
// kurala uymalıdır, aksi halde gerçekte olmayan bir durum test edilmiş olur.
#include "kernel/runtime.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::kernel;

namespace {

json::Value call(Runtime& rt, const std::string& method, const json::Value& payload) {
  std::string err;
  return json::parse(rt.call(method, payload.dump()), &err);
}

json::Value obj() { return json::Value::obj(); }

// Dizinin ilk elemanını güvenle okur — boşsa boş dizge.
std::string first(const json::Value& arr) {
  const auto& a = arr.asArray();
  return a.empty() ? std::string("") : a[0].asString();
}

// Sistem daveti oluşturur (admin akışının test karşılığı).
void seedInvite(Runtime& rt, const std::string& code, int maxUses = 1) {
  json::Value inv = obj();
  inv.set("code", code);
  inv.set("ownerId", "");
  inv.set("maxUses", maxUses);
  inv.set("usedCount", 0);
  inv.set("createdAt", rt.clock().now());
  inv.set("expiresAt", 0);
  inv.set("revoked", false);
  inv.set("redeemedBy", json::Value::arr());
  rt.store().put(coll::kInvites, code, inv);
}

json::Value redeem(Runtime& rt, const std::string& code, const std::string& name,
                   const std::string& type = "personal") {
  json::Value p = obj();
  p.set("code", code);
  p.set("name", name);
  p.set("accountType", type);
  return call(rt, "invite.redeem", p);
}

}  // namespace

TEST(api_ping_calisir) {
  Runtime rt("");
  const auto r = call(rt, "system.ping", obj());
  CHECK(r["ok"].asBool());
  CHECK(r["data"]["pong"].asBool());
}

TEST(api_bilinmeyen_metot_hata_doner) {
  Runtime rt("");
  const auto r = call(rt, "olmayan.metot", obj());
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_UNKNOWN_METHOD"));
}

TEST(api_bozuk_payload_cokmez) {
  Runtime rt("");
  std::string err;
  const auto r = json::parse(rt.call("system.ping", "{bozuk"), &err);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_BAD_PAYLOAD"));
}

TEST(api_gecersiz_davet_reddedilir) {
  Runtime rt("");
  json::Value p = obj();
  p.set("code", "YKB2Y7E3");
  const auto r = call(rt, "invite.check", p);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_INVITE_INVALID"));
}

TEST(api_dogru_davet_uyelik_bilgisi_doner) {
  Runtime rt("");
  seedInvite(rt, "HG2K7M9P");

  // Küçük harf ve tire ile yazılsa da tanınmalı
  json::Value chk = obj();
  chk.set("code", "hg2k7m-9p");
  const auto c = call(rt, "invite.check", chk);
  CHECK(c["ok"].asBool());
  CHECK(c["data"]["valid"].asBool());

  const auto r = redeem(rt, "HG2K7M9P", "Berke Kaan Saraç", "business");

  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["membership"]["memberNumber"].asInt(), 1);
  CHECK_EQ(r["data"]["user"]["handle"].asString(), std::string("berkekaansarac"));
  CHECK_EQ(r["data"]["user"]["accountType"].asString(), std::string("business"));
  // Yeni üyeye kendi davet kodları verilir (viral büyüme)
  CHECK_EQ(r["data"]["myInviteCodes"].asArray().size(), size_t(3));
}

TEST(api_ayni_davet_iki_kez_kullanilamaz) {
  Runtime rt("");
  seedInvite(rt, "TEK2KU7A");

  CHECK(redeem(rt, "TEK2KU7A", "Bir Kisi")["ok"].asBool());

  const auto r2 = redeem(rt, "TEK2KU7A", "Baska Kisi");
  CHECK(!r2["ok"].asBool());
  CHECK_EQ(r2["code"].asString(), std::string("ERR_INVITE_EXHAUSTED"));
}

TEST(api_isimsiz_kayit_reddedilir) {
  Runtime rt("");
  seedInvite(rt, "ADSZ4M7N");
  const auto r = redeem(rt, "ADSZ4M7N", "");
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_NAME_REQUIRED"));
}

TEST(api_gecersiz_hesap_turu_reddedilir) {
  Runtime rt("");
  seedInvite(rt, "HSP2T4R7");
  const auto r = redeem(rt, "HSP2T4R7", "Biri", "kral");
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_ACCOUNT_TYPE_INVALID"));
}

TEST(api_davet_agaci_kurulur) {
  Runtime rt("");
  seedInvite(rt, "KUY3B7VZ");

  const auto ilk = redeem(rt, "KUY3B7VZ", "Ilk Uye");
  CHECK(ilk["ok"].asBool());
  const std::string ilkId = ilk["data"]["user"]["id"].asString();
  const std::string cocukKod = first(ilk["data"]["myInviteCodes"]);
  CHECK(!cocukKod.empty());

  const auto ikinci = redeem(rt, cocukKod, "Ikinci Uye");
  CHECK(ikinci["ok"].asBool());
  CHECK_EQ(ikinci["data"]["membership"]["invitedByName"].asString(),
           std::string("Ilk Uye"));
  CHECK_EQ(ikinci["data"]["membership"]["memberNumber"].asInt(), 2);

  json::Value q = obj();
  q.set("userId", ilkId);
  const auto mine = call(rt, "invite.mine", q);
  CHECK(mine["ok"].asBool());
  CHECK_EQ(mine["data"]["codes"].asArray().size(), size_t(3));
}

TEST(api_akis_calisir_ve_profil_olusur) {
  Runtime rt("");
  seedInvite(rt, "AKS7TEST", 5);

  const auto meR = redeem(rt, "AKS7TEST", "Okuyucu");
  const std::string me = meR["data"]["user"]["id"].asString();
  const auto a1R = redeem(rt, "AKS7TEST", "Yazar Bir");
  const std::string a1 = a1R["data"]["user"]["id"].asString();
  CHECK(!me.empty());
  CHECK(!a1.empty());

  auto createPost = [&](const std::string& author, const std::string& topic,
                        const std::string& caption) {
    json::Value pp = obj();
    pp.set("authorId", author);
    pp.set("caption", caption);
    json::Value topics = json::Value::arr();
    topics.push(topic);
    pp.set("topics", topics);
    return call(rt, "post.create", pp)["data"]["id"].asString();
  };

  const std::string guzellikPost = createPost(a1, "guzellik", "Cilt bakımı");
  createPost(a1, "insaat", "Beton dökümü");

  for (int i = 0; i < 6; i++) {
    json::Value sg = obj();
    sg.set("userId", me);
    sg.set("itemId", guzellikPost);
    sg.set("kind", "like");
    CHECK(call(rt, "signal.record", sg)["ok"].asBool());
  }

  json::Value f = obj();
  f.set("userId", me);
  f.set("mode", "foryou");
  f.set("limit", 10);
  const auto feed = call(rt, "feed.get", f);

  CHECK(feed["ok"].asBool());
  CHECK(feed["data"]["items"].asArray().size() >= size_t(1));
  CHECK(feed["data"]["profileConfidence"].asNumber() > 0.0);
}

TEST(api_kendi_gonderin_akisinda_gorunmez) {
  Runtime rt("");
  seedInvite(rt, "KND2G7N4", 2);
  const std::string me = redeem(rt, "KND2G7N4", "Yazan")["data"]["user"]["id"].asString();

  json::Value pp = obj();
  pp.set("authorId", me);
  pp.set("caption", "kendi gönderim");
  call(rt, "post.create", pp);

  json::Value f = obj();
  f.set("userId", me);
  const auto feed = call(rt, "feed.get", f);
  CHECK(feed["ok"].asBool());
  CHECK_EQ(feed["data"]["items"].asArray().size(), size_t(0));
}

TEST(api_sinyal_profili_gunceller) {
  Runtime rt("");
  seedInvite(rt, "SNY4AK29", 3);
  const std::string me = redeem(rt, "SNY4AK29", "Sinyalci")["data"]["user"]["id"].asString();
  CHECK(!me.empty());

  json::Value pp = obj();
  pp.set("authorId", me);
  pp.set("caption", "test");
  json::Value topics = json::Value::arr();
  topics.push("medikal");
  pp.set("topics", topics);
  const std::string postId = call(rt, "post.create", pp)["data"]["id"].asString();

  json::Value s = obj();
  s.set("userId", me);
  s.set("itemId", postId);
  s.set("kind", "save");
  const auto r = call(rt, "signal.record", s);

  CHECK(r["ok"].asBool());
  CHECK(r["data"]["profileConfidence"].asNumber() > 0.0);

  const auto profile = rt.store().get(coll::kProfiles, me);
  CHECK(!profile.isNull());
  CHECK(profile["topics"]["medikal"].asNumber() > 0.0);
}

TEST(api_bilinmeyen_sinyal_reddedilir) {
  Runtime rt("");
  json::Value s = obj();
  s.set("userId", "u");
  s.set("itemId", "p");
  s.set("kind", "zıplama");
  const auto r = call(rt, "signal.record", s);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_SIGNAL_UNKNOWN"));
}

TEST(api_admin_yetkisiz_erisim_reddedilir) {
  Runtime rt("");
  const auto r = call(rt, "admin.overview", obj());
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_FORBIDDEN"));
}

TEST(api_admin_kurulum_ve_genel_bakis) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "kaan-gizli-anahtar");
  CHECK(call(rt, "admin.setup", setup)["ok"].asBool());

  json::Value zayif = obj();
  zayif.set("token", "kisa");
  CHECK(!call(rt, "admin.setup", zayif)["ok"].asBool());

  seedInvite(rt, "ADM2NTST", 3);
  redeem(rt, "ADM2NTST", "Uye Bir", "business");

  json::Value q = obj();
  q.set("adminToken", "kaan-gizli-anahtar");
  const auto ov = call(rt, "admin.overview", q);

  CHECK(ov["ok"].asBool());
  CHECK_EQ(ov["data"]["users"].asInt(), 1);
  CHECK_EQ(ov["data"]["business"].asInt(), 1);
  CHECK(ov["data"]["weights"]["interest"].asNumber() > 0.0);
}

TEST(api_admin_yanlis_token_reddedilir) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "dogru-anahtar-123");
  call(rt, "admin.setup", setup);

  json::Value q = obj();
  q.set("adminToken", "yanlis");
  CHECK(!call(rt, "admin.overview", q)["ok"].asBool());
}

TEST(api_admin_kullanici_detayi_mesajlari_gorur) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "kaan-gizli-anahtar");
  call(rt, "admin.setup", setup);

  seedInvite(rt, "DETAY493", 2);
  const std::string uid = redeem(rt, "DETAY493", "Mesajci")["data"]["user"]["id"].asString();
  CHECK(!uid.empty());

  // Mesajlaşma API'si v1.1'de gelir; admin görünürlüğü şimdiden çalışır.
  json::Value msg = obj();
  msg.set("fromId", uid);
  msg.set("toId", "birisi");
  msg.set("text", "Merhaba, randevu almak istiyorum");
  msg.set("at", rt.clock().now());
  rt.store().put(coll::kMessages, "m1", msg);

  json::Value q = obj();
  q.set("adminToken", "kaan-gizli-anahtar");
  q.set("userId", uid);
  const auto d = call(rt, "admin.user", q);

  CHECK(d["ok"].asBool());
  CHECK_EQ(d["data"]["messages"].asArray().size(), size_t(1));
  CHECK_EQ(d["data"]["messages"].asArray()[0]["text"].asString(),
           std::string("Merhaba, randevu almak istiyorum"));
  CHECK_EQ(d["data"]["invites"].asArray().size(), size_t(3));
}

TEST(api_admin_davet_uretir_ve_iptal_eder) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "kaan-gizli-anahtar");
  call(rt, "admin.setup", setup);

  json::Value q = obj();
  q.set("adminToken", "kaan-gizli-anahtar");
  q.set("count", 5);
  const auto r = call(rt, "admin.createInvites", q);
  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["codes"].asArray().size(), size_t(5));

  const std::string kod = first(r["data"]["codes"]);
  CHECK(!kod.empty());

  json::Value rev = obj();
  rev.set("adminToken", "kaan-gizli-anahtar");
  rev.set("code", kod);
  CHECK(call(rt, "admin.revokeInvite", rev)["ok"].asBool());

  const auto fail = redeem(rt, kod, "Deneyen");
  CHECK(!fail["ok"].asBool());
  CHECK_EQ(fail["code"].asString(), std::string("ERR_INVITE_REVOKED"));
}

TEST(api_admin_davet_agacini_doner) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "kaan-gizli-anahtar");
  call(rt, "admin.setup", setup);

  seedInvite(rt, "K3KUYE72");
  const auto ilk = redeem(rt, "K3KUYE72", "Kok");
  const std::string cocukKod = first(ilk["data"]["myInviteCodes"]);
  CHECK(!cocukKod.empty());
  redeem(rt, cocukKod, "Dal");

  json::Value q = obj();
  q.set("adminToken", "kaan-gizli-anahtar");
  const auto tree = call(rt, "admin.inviteTree", q);

  CHECK(tree["ok"].asBool());
  CHECK_EQ(tree["data"]["nodes"].asArray().size(), size_t(2));
  CHECK_EQ(tree["data"]["edges"].asArray().size(), size_t(1));
}

TEST(api_admin_icerik_kaldirinca_akistan_cikar) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "kaan-gizli-anahtar");
  call(rt, "admin.setup", setup);

  seedInvite(rt, "MD2R7N83", 3);
  const std::string me = redeem(rt, "MD2R7N83", "Okur")["data"]["user"]["id"].asString();
  const std::string yazar = redeem(rt, "MD2R7N83", "Yazar")["data"]["user"]["id"].asString();

  json::Value pp = obj();
  pp.set("authorId", yazar);
  pp.set("caption", "kaldirilacak");
  const std::string postId = call(rt, "post.create", pp)["data"]["id"].asString();

  json::Value rm = obj();
  rm.set("adminToken", "kaan-gizli-anahtar");
  rm.set("postId", postId);
  rm.set("reason", "kural ihlali");
  CHECK(call(rt, "admin.removePost", rm)["ok"].asBool());

  json::Value f = obj();
  f.set("userId", me);
  const auto feed = call(rt, "feed.get", f);
  CHECK_EQ(feed["data"]["items"].asArray().size(), size_t(0));
}

TEST(api_veri_diske_kalici_yazilir) {
  const std::string dir = "/tmp/hanagram_api_test";
  std::string uid;
  {
    Runtime rt(dir);
    seedInvite(rt, "KA7C2P89");
    uid = redeem(rt, "KA7C2P89", "Kalici Uye")["data"]["user"]["id"].asString();
    CHECK(!uid.empty());
    rt.flush();
  }
  {
    Runtime rt(dir);
    json::Value q = obj();
    q.set("userId", uid);
    const auto r = call(rt, "user.get", q);
    CHECK(r["ok"].asBool());
    CHECK_EQ(r["data"]["name"].asString(), std::string("Kalici Uye"));
  }
}

TEST(api_olay_yayini_calisir) {
  Runtime rt("");
  int sayac = 0;
  std::string sonKonu;
  rt.subscribe([&](const std::string& topic, const json::Value&) {
    sayac++;
    sonKonu = topic;
  });

  seedInvite(rt, "3AYTEST5");
  redeem(rt, "3AYTEST5", "Olayci");

  CHECK(sayac >= 2);  // invite.redeemed + user.joined
  CHECK_EQ(sonKonu, std::string("user.joined"));
}

TEST(api_profil_guncelleme) {
  Runtime rt("");
  seedInvite(rt, "PRF27K44", 2);
  const std::string uid = redeem(rt, "PRF27K44", "Eski Ad")["data"]["user"]["id"].asString();

  json::Value p = obj();
  p.set("userId", uid);
  p.set("name", "Yeni Ad");
  p.set("bio", "Kuaför · Kadıköy");
  p.set("sector", "Güzellik");
  const auto r = call(rt, "user.update", p);

  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["name"].asString(), std::string("Yeni Ad"));
  CHECK_EQ(r["data"]["handle"].asString(), std::string("yeniad"));
  CHECK_EQ(r["data"]["sector"].asString(), std::string("Güzellik"));
}
