// Hanagram — kimlik ve davet API'si
//
// Erken erişim akışı:
//   invite.check  → kod geçerli mi (kullanmadan sorar; giriş ekranı anlık geri bildirim verir)
//   invite.redeem → kodu kullan + hesabı oluştur → üyelik bilgileri döner
//   invite.mine   → kullanıcının dağıtabileceği kodlar
#include "../domain/identity/invite.hpp"
#include "../kernel/runtime.hpp"

namespace hg::kernel {

namespace {

using domain::Invite;
using domain::InviteStatus;

json::Value userPublic(const json::Value& u) {
  json::Value v = json::Value::obj();
  v.set("id", u["id"]);
  v.set("name", u["name"]);
  v.set("handle", u["handle"]);
  v.set("accountType", u["accountType"]);
  v.set("bio", u["bio"]);
  v.set("sector", u["sector"]);
  v.set("memberNumber", u["memberNumber"]);
  v.set("joinedAt", u["joinedAt"]);
  return v;
}

// TikTok tarzı @kullanıcıadı — Türkçe karakterler sadeleştirilir.
std::string handleFromName(const std::string& name) {
  static const std::pair<const char*, char> kMap[] = {
      {"ç", 'c'}, {"Ç", 'c'}, {"ğ", 'g'}, {"Ğ", 'g'}, {"ı", 'i'}, {"İ", 'i'},
      {"ö", 'o'}, {"Ö", 'o'}, {"ş", 's'}, {"Ş", 's'}, {"ü", 'u'}, {"Ü", 'u'},
  };
  std::string out;
  for (size_t i = 0; i < name.size();) {
    bool matched = false;
    for (const auto& [seq, rep] : kMap) {
      const size_t len = std::string(seq).size();
      if (name.compare(i, len, seq) == 0) {
        out += rep;
        i += len;
        matched = true;
        break;
      }
    }
    if (matched) continue;
    const unsigned char c = static_cast<unsigned char>(name[i]);
    if (c >= 'a' && c <= 'z') out += static_cast<char>(c);
    else if (c >= 'A' && c <= 'Z') out += static_cast<char>(c - 'A' + 'a');
    else if (c >= '0' && c <= '9') out += static_cast<char>(c);
    i++;
  }
  return out.empty() ? "hanagram" : out;
}

Invite loadInvite(Store& s, const std::string& code) {
  json::Value v = s.get(coll::kInvites, code);
  return v.isNull() ? Invite{} : Invite::fromJson(v);
}

}  // namespace

void registerIdentityApi(Runtime& rt) {
  // ——— Kodu doğrula (kullanmadan) ———
  rt.registerMethod("invite.check", [](Context& ctx, const json::Value& p) {
    const std::string code = domain::normalizeCode(p["code"].asString());
    if (code.empty()) return json::fail("ERR_INVITE_INVALID", "invite.retry");

    Invite inv = loadInvite(ctx.store, code);
    const InviteStatus st = domain::checkInvite(inv, ctx.clock.now());
    if (st != InviteStatus::Valid) {
      return json::fail(domain::inviteErrorCode(st), "invite.retry");
    }

    json::Value owner = inv.ownerId.empty() ? json::Value()
                                            : ctx.store.get(coll::kUsers, inv.ownerId);
    json::Value v = json::Value::obj();
    v.set("valid", true);
    v.set("code", inv.code);
    v.set("invitedByName", owner.isNull() ? std::string("Hanagram") : owner["name"].asString());
    v.set("remainingUses", inv.maxUses - inv.usedCount);
    return json::ok(v);
  });

  // ——— Kodu kullan + hesap oluştur ———
  rt.registerMethod("invite.redeem", [](Context& ctx, const json::Value& p) {
    const std::string code = domain::normalizeCode(p["code"].asString());
    const std::string name = p["name"].asString();
    std::string accountType = p["accountType"].asString();
    if (accountType.empty()) accountType = "personal";

    if (name.empty()) return json::fail("ERR_NAME_REQUIRED", "form.name");
    if (accountType != "personal" && accountType != "creator" && accountType != "business") {
      return json::fail("ERR_ACCOUNT_TYPE_INVALID", "form.accountType");
    }

    Invite inv = loadInvite(ctx.store, code);
    const int64_t now = ctx.clock.now();
    const InviteStatus st = domain::checkInvite(inv, now);
    if (st != InviteStatus::Valid) {
      return json::fail(domain::inviteErrorCode(st), "invite.retry");
    }

    // Üye numarası: kaçıncı kişi olduğunu gösterir (erken erişim rozeti).
    const int64_t memberNumber = static_cast<int64_t>(ctx.store.count(coll::kUsers)) + 1;
    const std::string userId = ctx.ids.next(now);

    json::Value user = json::Value::obj();
    user.set("id", userId);
    user.set("name", name);
    user.set("handle", handleFromName(name));
    user.set("accountType", accountType);
    user.set("bio", "");
    user.set("sector", "");
    user.set("invitedBy", inv.ownerId);
    user.set("inviteCode", inv.code);
    user.set("memberNumber", memberNumber);
    user.set("joinedAt", now);
    user.set("earlyAccess", true);
    user.set("suspended", false);
    user.set("followers", 0);
    user.set("following", 0);
    ctx.store.put(coll::kUsers, userId, user);

    // Daveti işaretle
    inv.usedCount++;
    inv.redeemedBy.push_back(userId);
    ctx.store.put(coll::kInvites, inv.code, inv.toJson());

    // Yeni üyeye kendi davet kodları — viral büyüme + davet ağacı
    json::Value myCodes = json::Value::arr();
    for (int i = 0; i < domain::kDefaultInviteQuota; i++) {
      Invite child;
      child.code = ctx.ids.code(domain::kInviteCodeLength);
      child.ownerId = userId;
      child.maxUses = 1;
      child.createdAt = now;
      child.expiresAt = now + domain::kInviteTtlMs;
      ctx.store.put(coll::kInvites, child.code, child.toJson());
      myCodes.push(child.code);
    }

    json::Value inviter = inv.ownerId.empty() ? json::Value()
                                              : ctx.store.get(coll::kUsers, inv.ownerId);

    domain::Membership m;
    m.code = inv.code;
    m.invitedByUserId = inv.ownerId;
    m.invitedByName = inviter.isNull() ? "Hanagram" : inviter["name"].asString();
    m.memberNumber = memberNumber;
    m.inviteQuota = domain::kDefaultInviteQuota;
    m.joinedAt = now;

    ctx.bus.emit(topics::kInviteRedeemed, user);
    ctx.bus.emit(topics::kUserJoined, user);

    json::Value v = json::Value::obj();
    v.set("user", userPublic(user));
    v.set("membership", m.toJson());
    v.set("myInviteCodes", myCodes);
    return json::ok(v);
  });

  // ——— Kullanıcının davet kodları ———
  rt.registerMethod("invite.mine", [](Context& ctx, const json::Value& p) {
    const std::string userId = p["userId"].asString();
    const int64_t now = ctx.clock.now();

    auto rows = ctx.store.where(coll::kInvites, [&](const json::Value& v) {
      return v["ownerId"].asString() == userId;
    });

    json::Value arr = json::Value::arr();
    for (const auto& r : rows) {
      Invite inv = Invite::fromJson(r.data);
      json::Value item = json::Value::obj();
      item.set("code", inv.code);
      item.set("used", inv.usedCount > 0);
      item.set("status", domain::inviteErrorCode(domain::checkInvite(inv, now)));
      item.set("expiresAt", inv.expiresAt);
      if (!inv.redeemedBy.empty()) {
        json::Value who = ctx.store.get(coll::kUsers, inv.redeemedBy.front());
        item.set("redeemedByName", who.isNull() ? std::string("") : who["name"].asString());
      }
      arr.push(item);
    }
    json::Value v = json::Value::obj();
    v.set("codes", arr);
    return json::ok(v);
  });

  // ——— Kullanıcı ———
  rt.registerMethod("user.get", [](Context& ctx, const json::Value& p) {
    json::Value u = ctx.store.get(coll::kUsers, p["userId"].asString());
    if (u.isNull()) return json::fail("ERR_USER_NOT_FOUND");
    return json::ok(userPublic(u));
  });

  rt.registerMethod("user.update", [](Context& ctx, const json::Value& p) {
    const std::string id = p["userId"].asString();
    json::Value u = ctx.store.get(coll::kUsers, id);
    if (u.isNull()) return json::fail("ERR_USER_NOT_FOUND");

    for (const char* field : {"name", "bio", "sector", "accountType", "photoUri",
                              "businessName", "address", "phone", "primaryAction"}) {
      if (p.has(field)) u.set(field, p[field]);
    }
    if (p.has("name")) u.set("handle", handleFromName(p["name"].asString()));
    ctx.store.put(coll::kUsers, id, u);
    ctx.bus.emit(topics::kProfileUpdated, u);
    return json::ok(userPublic(u));
  });
}

}  // namespace hg::kernel
