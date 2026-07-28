// Mesajlaşma testleri — SÖZLEŞME. Ajan bu dosyayı DEĞİŞTİREMEZ.
// Görev: bu testleri geçiren domain/social/messaging.cpp ve api/messaging.cpp yazmak.
#include "domain/social/messaging.hpp"
#include "kernel/runtime.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::domain;
using namespace hg::kernel;

namespace {

json::Value call(Runtime& rt, const std::string& m, const json::Value& p) {
  std::string err;
  return json::parse(rt.call(m, p.dump()), &err);
}

json::Value obj() { return json::Value::obj(); }

void seedInvite(Runtime& rt, const std::string& code, int maxUses) {
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

std::string join(Runtime& rt, const std::string& code, const std::string& name) {
  json::Value p = obj();
  p.set("code", code);
  p.set("name", name);
  p.set("accountType", "personal");
  return call(rt, "invite.redeem", p)["data"]["user"]["id"].asString();
}

}  // namespace

// ——— Saf alan mantığı ———

TEST(mesaj_sohbet_kimligi_sirasiz_ayni) {
  const auto ab = threadIdFor("u2", "u9");
  const auto ba = threadIdFor("u9", "u2");
  CHECK(!ab.empty());
  CHECK_EQ(ab, ba);
}

TEST(mesaj_kendine_sohbet_yok) {
  CHECK_EQ(threadIdFor("u1", "u1"), std::string(""));
}

TEST(mesaj_farkli_ciftler_farkli_sohbet) {
  CHECK(threadIdFor("a", "b") != threadIdFor("a", "c"));
}

TEST(mesaj_metni_kirpilir) {
  std::string out;
  CHECK(sanitizeMessageText("  merhaba  ", out));
  CHECK_EQ(out, std::string("merhaba"));
}

TEST(mesaj_bos_metin_reddedilir) {
  std::string out = "dokunulmadi";
  CHECK(!sanitizeMessageText("   ", out));
  CHECK_EQ(out, std::string("dokunulmadi"));
  CHECK(!sanitizeMessageText("", out));
}

TEST(mesaj_uzun_metin_kirpilir_hata_degil) {
  const std::string uzun(kMaxMessageLength + 500, 'a');
  std::string out;
  CHECK(sanitizeMessageText(uzun, out));
  CHECK_EQ(out.size(), kMaxMessageLength);
}

TEST(mesaj_thread_karsi_taraf) {
  Thread t;
  t.userA = "a";
  t.userB = "b";
  CHECK_EQ(t.other("a"), std::string("b"));
  CHECK_EQ(t.other("b"), std::string("a"));
  CHECK_EQ(t.other("yabanci"), std::string(""));
}

TEST(mesaj_okunmamis_hesabi) {
  Thread t;
  t.userA = "a";
  t.userB = "b";
  t.lastAt = 1000;
  t.readA = 1000;
  t.readB = 500;
  CHECK(!t.hasUnread("a"));
  CHECK(t.hasUnread("b"));
}

TEST(mesaj_json_gidis_donus) {
  Message m;
  m.id = "m1";
  m.threadId = "t1";
  m.fromId = "a";
  m.toId = "b";
  m.text = "Merhaba, randevu almak istiyorum";
  m.at = 1700000000000;
  const auto back = Message::fromJson(m.toJson());
  CHECK_EQ(back.id, m.id);
  CHECK_EQ(back.text, m.text);
  CHECK_EQ(back.at, m.at);

  Thread t;
  t.id = "t1";
  t.userA = "a";
  t.userB = "b";
  t.lastText = "son";
  t.messageCount = 3;
  t.readA = 5;
  const auto tb = Thread::fromJson(t.toJson());
  CHECK_EQ(tb.id, t.id);
  CHECK_EQ(tb.messageCount, int64_t(3));
  CHECK_EQ(tb.readA, int64_t(5));
}

// ——— API akışları ———

TEST(api_mesaj_gonder_ve_sohbet_olusur) {
  Runtime rt("");
  seedInvite(rt, "MSG2T7K4", 3);
  const auto a = join(rt, "MSG2T7K4", "Ahmet Yilmaz");
  const auto b = join(rt, "MSG2T7K4", "Elif Kaya");

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", b);
  p.set("text", "  Merhaba  ");
  const auto r = call(rt, "message.send", p);

  CHECK(r["ok"].asBool());
  CHECK_EQ(r["data"]["message"]["text"].asString(), std::string("Merhaba"));
  CHECK(!r["data"]["message"]["threadId"].asString().empty());
  CHECK_EQ(r["data"]["thread"]["messageCount"].asInt(), 1);
}

TEST(api_mesaj_bos_metin_reddedilir) {
  Runtime rt("");
  seedInvite(rt, "MSG3B8N5", 3);
  const auto a = join(rt, "MSG3B8N5", "Bir");
  const auto b = join(rt, "MSG3B8N5", "Iki");

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", b);
  p.set("text", "   ");
  const auto r = call(rt, "message.send", p);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_MESSAGE_EMPTY"));
}

TEST(api_mesaj_kendine_gonderilemez) {
  Runtime rt("");
  seedInvite(rt, "MSG4C9P6", 2);
  const auto a = join(rt, "MSG4C9P6", "Yalniz");

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", a);
  p.set("text", "kendime");
  const auto r = call(rt, "message.send", p);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_SELF_MESSAGE"));
}

TEST(api_mesaj_olmayan_kullaniciya_gonderilemez) {
  Runtime rt("");
  seedInvite(rt, "MSG5D2Q7", 2);
  const auto a = join(rt, "MSG5D2Q7", "Gonderen");

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", "olmayan-kullanici");
  p.set("text", "merhaba");
  const auto r = call(rt, "message.send", p);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_USER_NOT_FOUND"));
}

TEST(api_mesaj_askiya_alinmis_kullanici_gonderemez) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "kaan-gizli-anahtar");
  call(rt, "admin.setup", setup);

  seedInvite(rt, "MSG6E3R8", 3);
  const auto a = join(rt, "MSG6E3R8", "Askili");
  const auto b = join(rt, "MSG6E3R8", "Normal");

  json::Value sus = obj();
  sus.set("adminToken", "kaan-gizli-anahtar");
  sus.set("userId", a);
  sus.set("suspended", true);
  CHECK(call(rt, "admin.suspendUser", sus)["ok"].asBool());

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", b);
  p.set("text", "merhaba");
  const auto r = call(rt, "message.send", p);
  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_USER_SUSPENDED"));
}

TEST(api_mesaj_ayni_cift_tek_sohbette_birikir) {
  Runtime rt("");
  seedInvite(rt, "MSG7F4S9", 3);
  const auto a = join(rt, "MSG7F4S9", "Aci");
  const auto b = join(rt, "MSG7F4S9", "Beci");

  auto send = [&](const std::string& from, const std::string& to, const std::string& t) {
    json::Value p = obj();
    p.set("fromId", from);
    p.set("toId", to);
    p.set("text", t);
    return call(rt, "message.send", p);
  };

  const auto r1 = send(a, b, "birinci");
  const auto r2 = send(b, a, "ikinci");   // ters yön aynı sohbete düşmeli
  const auto r3 = send(a, b, "ucuncu");

  const auto t1 = r1["data"]["message"]["threadId"].asString();
  CHECK_EQ(r2["data"]["message"]["threadId"].asString(), t1);
  CHECK_EQ(r3["data"]["thread"]["messageCount"].asInt(), 3);
  CHECK_EQ(r3["data"]["thread"]["lastText"].asString(), std::string("ucuncu"));
}

TEST(api_sohbet_listesi_yeniden_eskiye) {
  Runtime rt("");
  seedInvite(rt, "MSG8G5T2", 4);
  const auto me = join(rt, "MSG8G5T2", "Ben");
  const auto x = join(rt, "MSG8G5T2", "Iks");
  const auto y = join(rt, "MSG8G5T2", "Ipsilon");

  auto send = [&](const std::string& to, const std::string& t) {
    json::Value p = obj();
    p.set("fromId", me);
    p.set("toId", to);
    p.set("text", t);
    call(rt, "message.send", p);
  };
  send(x, "ilk");
  send(y, "sonraki");

  json::Value q = obj();
  q.set("userId", me);
  const auto r = call(rt, "message.threads", q);

  CHECK(r["ok"].asBool());
  const auto& threads = r["data"]["threads"].asArray();
  CHECK_EQ(threads.size(), size_t(2));
  // En son yazışılan başta
  CHECK_EQ(threads[0]["lastText"].asString(), std::string("sonraki"));
  // Karşı tarafın adı listede olmalı — arayüz ek sorgu yapmasın
  CHECK_EQ(threads[0]["otherName"].asString(), std::string("Ipsilon"));
}

TEST(api_mesaj_gecmisi_eskiden_yeniye) {
  Runtime rt("");
  seedInvite(rt, "MSG9H6U3", 3);
  const auto a = join(rt, "MSG9H6U3", "Anlatan");
  const auto b = join(rt, "MSG9H6U3", "Dinleyen");

  std::string threadId;
  for (int i = 1; i <= 5; i++) {
    json::Value p = obj();
    p.set("fromId", a);
    p.set("toId", b);
    p.set("text", "mesaj" + std::to_string(i));
    threadId = call(rt, "message.send", p)["data"]["message"]["threadId"].asString();
  }

  json::Value q = obj();
  q.set("userId", b);
  q.set("threadId", threadId);
  const auto r = call(rt, "message.history", q);

  CHECK(r["ok"].asBool());
  const auto& msgs = r["data"]["messages"].asArray();
  CHECK_EQ(msgs.size(), size_t(5));
  CHECK_EQ(msgs[0]["text"].asString(), std::string("mesaj1"));
  CHECK_EQ(msgs[4]["text"].asString(), std::string("mesaj5"));
}

TEST(api_yabanci_sohbet_gecmisini_goremez) {
  Runtime rt("");
  seedInvite(rt, "MSGAJ7V4", 4);
  const auto a = join(rt, "MSGAJ7V4", "Birinci");
  const auto b = join(rt, "MSGAJ7V4", "Ikinci");
  const auto c = join(rt, "MSGAJ7V4", "Ucuncu");

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", b);
  p.set("text", "gizli");
  const auto threadId =
      call(rt, "message.send", p)["data"]["message"]["threadId"].asString();

  json::Value q = obj();
  q.set("userId", c);  // sohbete dahil değil
  q.set("threadId", threadId);
  const auto r = call(rt, "message.history", q);

  CHECK(!r["ok"].asBool());
  CHECK_EQ(r["code"].asString(), std::string("ERR_FORBIDDEN"));
}

TEST(api_okundu_isaretleme) {
  Runtime rt("");
  seedInvite(rt, "MSGBK8W5", 3);
  const auto a = join(rt, "MSGBK8W5", "Yazan");
  const auto b = join(rt, "MSGBK8W5", "Okuyan");

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", b);
  p.set("text", "okunacak");
  const auto threadId =
      call(rt, "message.send", p)["data"]["message"]["threadId"].asString();

  json::Value q = obj();
  q.set("userId", b);
  const auto before = call(rt, "message.threads", q);
  CHECK(before["data"]["threads"].asArray()[0]["unread"].asBool());

  json::Value mr = obj();
  mr.set("userId", b);
  mr.set("threadId", threadId);
  CHECK(call(rt, "message.read", mr)["ok"].asBool());

  const auto after = call(rt, "message.threads", q);
  CHECK(!after["data"]["threads"].asArray()[0]["unread"].asBool());
}

TEST(api_mesajlar_admin_tarafindan_gorunur) {
  Runtime rt("");
  json::Value setup = obj();
  setup.set("token", "kaan-gizli-anahtar");
  call(rt, "admin.setup", setup);

  seedInvite(rt, "MSGCK9X6", 3);
  const auto a = join(rt, "MSGCK9X6", "Konusan");
  const auto b = join(rt, "MSGCK9X6", "Dinleyen");

  json::Value p = obj();
  p.set("fromId", a);
  p.set("toId", b);
  p.set("text", "Randevu almak istiyorum");
  call(rt, "message.send", p);

  json::Value q = obj();
  q.set("adminToken", "kaan-gizli-anahtar");
  q.set("userId", a);
  const auto d = call(rt, "admin.user", q);

  CHECK(d["ok"].asBool());
  CHECK_EQ(d["data"]["messages"].asArray().size(), size_t(1));
  CHECK_EQ(d["data"]["messages"].asArray()[0]["text"].asString(),
           std::string("Randevu almak istiyorum"));
}

TEST(api_mesajlar_diske_kalici) {
  const std::string dir = "/tmp/hanagram_msg_test";
  std::string threadId, b;
  {
    Runtime rt(dir);
    seedInvite(rt, "MSGDM2Y7", 3);
    const auto x = join(rt, "MSGDM2Y7", "Kalici Yazan");
    b = join(rt, "MSGDM2Y7", "Kalici Okuyan");
    json::Value p = obj();
    p.set("fromId", x);
    p.set("toId", b);
    p.set("text", "kalici mesaj");
    threadId = call(rt, "message.send", p)["data"]["message"]["threadId"].asString();
    rt.flush();
  }
  {
    Runtime rt(dir);
    json::Value q = obj();
    q.set("userId", b);
    q.set("threadId", threadId);
    const auto r = call(rt, "message.history", q);
    CHECK(r["ok"].asBool());
    CHECK_EQ(r["data"]["messages"].asArray()[0]["text"].asString(),
             std::string("kalici mesaj"));
  }
}
