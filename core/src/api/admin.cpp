// Hanagram — admin API (Kaan)
//
// Admin TAM YETKİLİDİR: her kullanıcıyı, ne iş yaptığını, içeriklerini ve mesajlarını
// görebilir; davet üretebilir/iptal edebilir; içerik kaldırabilir; algoritmanın nasıl
// öğrendiğini izleyebilir.
//
// Güvenlik notu: yetki kontrolü ÇEKİRDEKTE yapılır (adminToken), arayüzde değil.
// Arayüzde saklanan bir bayrak yetki değildir.
#include <algorithm>

#include "../kernel/runtime.hpp"

namespace hg::kernel {

namespace {

bool isAdmin(Context& ctx, const json::Value& p) {
  json::Value cfg = ctx.store.get(coll::kSystem, "admin");
  const std::string expected = cfg["token"].asString();
  if (expected.empty()) return false;
  return p["adminToken"].asString() == expected;
}

json::Value denied() { return json::fail("ERR_FORBIDDEN", "admin.login"); }

}  // namespace

void registerAdminApi(Runtime& rt) {
  // ——— Admin kurulumu: ilk çağrıda token belirlenir ———
  rt.registerMethod("admin.setup", [](Context& ctx, const json::Value& p) {
    json::Value cfg = ctx.store.get(coll::kSystem, "admin");
    const std::string token = p["token"].asString();
    if (token.size() < 8) return json::fail("ERR_TOKEN_WEAK", "admin.token");

    // Zaten kurulmuşsa yalnızca mevcut token ile değiştirilebilir.
    if (!cfg["token"].asString().empty() &&
        cfg["token"].asString() != p["currentToken"].asString()) {
      return denied();
    }
    json::Value next = json::Value::obj();
    next.set("token", token);
    next.set("updatedAt", ctx.clock.now());
    ctx.store.put(coll::kSystem, "admin", next);
    return json::ok(json::Value::obj());
  });

  // ——— Genel bakış ———
  rt.registerMethod("admin.overview", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    const int64_t now = ctx.clock.now();

    int64_t personal = 0, creator = 0, business = 0, suspended = 0;
    int64_t joined24h = 0;
    for (const auto& r : ctx.store.all(coll::kUsers)) {
      const std::string t = r.data["accountType"].asString();
      if (t == "creator") creator++;
      else if (t == "business") business++;
      else personal++;
      if (r.data["suspended"].asBool()) suspended++;
      if (now - r.data["joinedAt"].asInt() < kDay) joined24h++;
    }

    int64_t posts24h = 0;
    for (const auto& r : ctx.store.all(coll::kPosts)) {
      if (now - r.data["createdAt"].asInt() < kDay) posts24h++;
    }

    int64_t invitesOpen = 0, invitesUsed = 0;
    for (const auto& r : ctx.store.all(coll::kInvites)) {
      if (r.data["usedCount"].asInt() > 0) invitesUsed++;
      else if (!r.data["revoked"].asBool()) invitesOpen++;
    }

    json::Value v = json::Value::obj();
    v.set("users", static_cast<int64_t>(ctx.store.count(coll::kUsers)));
    v.set("personal", personal);
    v.set("creator", creator);
    v.set("business", business);
    v.set("suspended", suspended);
    v.set("joined24h", joined24h);
    v.set("posts", static_cast<int64_t>(ctx.store.count(coll::kPosts)));
    v.set("posts24h", posts24h);
    v.set("signals", static_cast<int64_t>(ctx.store.count(coll::kSignals)));
    v.set("invitesOpen", invitesOpen);
    v.set("invitesUsed", invitesUsed);
    v.set("algo", ctx.learner.stats());
    v.set("weights", ctx.ranker.weights().toJson());
    return json::ok(v);
  });

  // ——— Kullanıcı listesi: kim, ne iş yapıyor ———
  rt.registerMethod("admin.users", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    const std::string q = p["query"].asString();

    auto rows = ctx.store.all(coll::kUsers);
    json::Value arr = json::Value::arr();
    for (const auto& r : rows) {
      const json::Value& u = r.data;
      if (!q.empty()) {
        const std::string hay = u["name"].asString() + " " + u["handle"].asString() + " " +
                                u["sector"].asString();
        if (hay.find(q) == std::string::npos) continue;
      }
      json::Value inviter = u["invitedBy"].asString().empty()
                                ? json::Value()
                                : ctx.store.get(coll::kUsers, u["invitedBy"].asString());

      int64_t postCount = 0;
      for (const auto& pr : ctx.store.where(coll::kPosts, [&](const json::Value& pv) {
             return pv["authorId"].asString() == u["id"].asString();
           })) {
        (void)pr;
        postCount++;
      }

      json::Value item = json::Value::obj();
      item.set("id", u["id"]);
      item.set("name", u["name"]);
      item.set("handle", u["handle"]);
      item.set("accountType", u["accountType"]);
      item.set("sector", u["sector"]);
      item.set("memberNumber", u["memberNumber"]);
      item.set("joinedAt", u["joinedAt"]);
      item.set("suspended", u["suspended"]);
      item.set("invitedByName", inviter.isNull() ? std::string("Hanagram")
                                                 : inviter["name"].asString());
      item.set("postCount", postCount);
      arr.push(item);
    }

    json::Value v = json::Value::obj();
    v.set("users", arr);
    return json::ok(v);
  });

  // ——— Kullanıcı detayı: içerik + mesaj + ilgi profili ———
  rt.registerMethod("admin.user", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    const std::string id = p["userId"].asString();
    json::Value u = ctx.store.get(coll::kUsers, id);
    if (u.isNull()) return json::fail("ERR_USER_NOT_FOUND");

    json::Value posts = json::Value::arr();
    for (const auto& r : ctx.store.where(coll::kPosts, [&](const json::Value& pv) {
           return pv["authorId"].asString() == id;
         })) {
      posts.push(r.data);
    }

    // Mesajlar — admin tam görünürlüğe sahip (Kaan'ın açık isteği).
    json::Value messages = json::Value::arr();
    for (const auto& r : ctx.store.where(coll::kMessages, [&](const json::Value& mv) {
           return mv["fromId"].asString() == id || mv["toId"].asString() == id;
         })) {
      messages.push(r.data);
    }

    json::Value signals = json::Value::arr();
    {
      auto rows = ctx.store.where(coll::kSignals, [&](const json::Value& sv) {
        return sv["userId"].asString() == id;
      });
      // Son 100 sinyal
      const size_t start = rows.size() > 100 ? rows.size() - 100 : 0;
      for (size_t i = start; i < rows.size(); i++) signals.push(rows[i].data);
    }

    json::Value invites = json::Value::arr();
    for (const auto& r : ctx.store.where(coll::kInvites, [&](const json::Value& iv) {
           return iv["ownerId"].asString() == id;
         })) {
      invites.push(r.data);
    }

    json::Value v = json::Value::obj();
    v.set("user", u);
    v.set("posts", posts);
    v.set("messages", messages);
    v.set("signals", signals);
    v.set("invites", invites);
    v.set("interestProfile", ctx.store.get(coll::kProfiles, id));
    return json::ok(v);
  });

  // ——— Davet ağacı: kim kimi getirdi ———
  rt.registerMethod("admin.inviteTree", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();

    json::Value nodes = json::Value::arr();
    json::Value edges = json::Value::arr();
    for (const auto& r : ctx.store.all(coll::kUsers)) {
      const json::Value& u = r.data;
      json::Value n = json::Value::obj();
      n.set("id", u["id"]);
      n.set("name", u["name"]);
      n.set("accountType", u["accountType"]);
      n.set("memberNumber", u["memberNumber"]);
      n.set("joinedAt", u["joinedAt"]);
      nodes.push(n);

      const std::string parent = u["invitedBy"].asString();
      if (!parent.empty()) {
        json::Value e = json::Value::obj();
        e.set("from", parent);
        e.set("to", u["id"]);
        edges.push(e);
      }
    }
    json::Value v = json::Value::obj();
    v.set("nodes", nodes);
    v.set("edges", edges);
    return json::ok(v);
  });

  // ——— Davet üret ———
  rt.registerMethod("admin.createInvites", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    const int count = std::clamp(static_cast<int>(p["count"].asInt(1)), 1, 100);
    const int maxUses = std::clamp(static_cast<int>(p["maxUses"].asInt(1)), 1, 1000);
    const int64_t now = ctx.clock.now();

    json::Value arr = json::Value::arr();
    for (int i = 0; i < count; i++) {
      json::Value inv = json::Value::obj();
      const std::string code = ctx.ids.code(8);
      inv.set("code", code);
      inv.set("ownerId", "");  // sistem daveti
      inv.set("maxUses", maxUses);
      inv.set("usedCount", 0);
      inv.set("createdAt", now);
      inv.set("expiresAt", p["expiresAt"].asInt(0));
      inv.set("revoked", false);
      inv.set("redeemedBy", json::Value::arr());
      ctx.store.put(coll::kInvites, code, inv);
      arr.push(code);
    }
    json::Value v = json::Value::obj();
    v.set("codes", arr);
    return json::ok(v);
  });

  // ——— Moderasyon ———
  rt.registerMethod("admin.suspendUser", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    json::Value u = ctx.store.get(coll::kUsers, p["userId"].asString());
    if (u.isNull()) return json::fail("ERR_USER_NOT_FOUND");
    u.set("suspended", p["suspended"].asBool());
    ctx.store.put(coll::kUsers, p["userId"].asString(), u);
    return json::ok(u);
  });

  rt.registerMethod("admin.removePost", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    json::Value post = ctx.store.get(coll::kPosts, p["postId"].asString());
    if (post.isNull()) return json::fail("ERR_POST_NOT_FOUND");
    post.set("removed", true);
    post.set("removedReason", p["reason"]);
    ctx.store.put(coll::kPosts, p["postId"].asString(), post);
    return json::ok(post);
  });

  rt.registerMethod("admin.revokeInvite", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    json::Value inv = ctx.store.get(coll::kInvites, p["code"].asString());
    if (inv.isNull()) return json::fail("ERR_INVITE_INVALID");
    inv.set("revoked", true);
    ctx.store.put(coll::kInvites, p["code"].asString(), inv);
    return json::ok(inv);
  });

  // ——— Algoritma paneli: nasıl öğreniyor ———
  rt.registerMethod("admin.algo", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();

    json::Value history = json::Value::arr();
    auto rows = ctx.store.all(coll::kCalibrations);
    const size_t start = rows.size() > 50 ? rows.size() - 50 : 0;
    for (size_t i = start; i < rows.size(); i++) history.push(rows[i].data);

    json::Value v = json::Value::obj();
    v.set("weights", ctx.ranker.weights().toJson());
    v.set("stats", ctx.learner.stats());
    v.set("brier", ctx.learner.brier(ctx.ranker.weights()));
    v.set("history", history);
    return json::ok(v);
  });

  // ——— Kalibrasyonu elle tetikle ———
  rt.registerMethod("admin.calibrate", [](Context& ctx, const json::Value& p) {
    if (!isAdmin(ctx, p)) return denied();
    return ctx.rt.tick();
  });
}

}  // namespace hg::kernel
