#include "invite.hpp"

namespace hg::domain {

const char* inviteErrorCode(InviteStatus s) {
  switch (s) {
    case InviteStatus::Valid:     return "OK";
    case InviteStatus::NotFound:  return "ERR_INVITE_INVALID";
    case InviteStatus::Revoked:   return "ERR_INVITE_REVOKED";
    case InviteStatus::Expired:   return "ERR_INVITE_EXPIRED";
    case InviteStatus::Exhausted: return "ERR_INVITE_EXHAUSTED";
  }
  return "ERR_INVITE_INVALID";
}

std::string normalizeCode(const std::string& raw) {
  std::string out;
  out.reserve(raw.size());
  for (unsigned char c : raw) {
    // Yalnızca ASCII harf/rakam kalır; tire, boşluk, "HG-" öneki temizlenir.
    if (c >= 'a' && c <= 'z') {
      out += static_cast<char>(c - 'a' + 'A');
    } else if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
      out += static_cast<char>(c);
    }
  }
  // Yaygın karıştırmalar: kullanıcı O yazdıysa 0, I/L yazdıysa 1 kastetmiştir.
  // Kod alfabesinde O, I, L yok (bkz. kernel/id.cpp).
  for (auto& c : out) {
    if (c == 'O') c = '0';
    else if (c == 'I' || c == 'L') c = '1';
  }
  // Bilinçli olarak marka öneki ("HG-") ayıklanmaz: kod alfabesinde H ve G
  // bulunduğu için gerçek bir kod da "HG" ile başlayabilir ve ayıklama onu bozar.
  // Kodlar öneksiz sunulur.
  return out;
}

InviteStatus checkInvite(const Invite& inv, int64_t now) {
  if (inv.code.empty()) return InviteStatus::NotFound;
  if (inv.revoked) return InviteStatus::Revoked;
  if (inv.expiresAt > 0 && now > inv.expiresAt) return InviteStatus::Expired;
  if (inv.exhausted()) return InviteStatus::Exhausted;
  return InviteStatus::Valid;
}

json::Value Invite::toJson() const {
  json::Value redeemed = json::Value::arr();
  for (const auto& u : redeemedBy) redeemed.push(u);

  json::Value v = json::Value::obj();
  v.set("code", code);
  v.set("ownerId", ownerId);
  v.set("maxUses", maxUses);
  v.set("usedCount", usedCount);
  v.set("createdAt", createdAt);
  v.set("expiresAt", expiresAt);
  v.set("revoked", revoked);
  v.set("redeemedBy", redeemed);
  return v;
}

Invite Invite::fromJson(const json::Value& v) {
  Invite i;
  i.code = v["code"].asString();
  i.ownerId = v["ownerId"].asString();
  i.maxUses = static_cast<int>(v["maxUses"].asInt(1));
  i.usedCount = static_cast<int>(v["usedCount"].asInt(0));
  i.createdAt = v["createdAt"].asInt();
  i.expiresAt = v["expiresAt"].asInt();
  i.revoked = v["revoked"].asBool();
  for (const auto& u : v["redeemedBy"].asArray()) i.redeemedBy.push_back(u.asString());
  return i;
}

json::Value Membership::toJson() const {
  json::Value v = json::Value::obj();
  v.set("code", code);
  v.set("invitedByUserId", invitedByUserId);
  v.set("invitedByName", invitedByName);
  v.set("memberNumber", memberNumber);
  v.set("inviteQuota", inviteQuota);
  v.set("earlyAccess", earlyAccess);
  v.set("joinedAt", joinedAt);
  return v;
}

}  // namespace hg::domain
