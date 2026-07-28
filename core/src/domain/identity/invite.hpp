// Hanagram — davet (referans) sistemi
//
// Erken erişim aşamasında üyelik yok: giriş DAVET KODU ile olur. Doğru kod girilince
// kullanıcıya üyelik bilgileri gösterilir (kim davet etti, kaçıncı üye, kaç davet hakkı).
//
// Neden böyle: kontrollü büyüme + gerçek kullanıcı + davet ağacı üzerinden kimin kimi
// getirdiğinin izlenebilmesi (admin paneli bunu görselleştirir).
#pragma once

#include <string>
#include <vector>

#include "../../kernel/clock.hpp"
#include "../../util/json.hpp"

namespace hg::domain {

struct Invite {
  std::string code;        // normalize edilmiş, büyük harf
  std::string ownerId;     // üreten kullanıcı; boş = sistem tarafından üretildi
  int maxUses = 1;
  int usedCount = 0;
  int64_t createdAt = 0;
  int64_t expiresAt = 0;   // 0 = süresiz
  bool revoked = false;
  std::vector<std::string> redeemedBy;  // kullanan kullanıcı kimlikleri

  bool exhausted() const { return usedCount >= maxUses; }
  json::Value toJson() const;
  static Invite fromJson(const json::Value& v);
};

// Kod doğrulama sonucu.
enum class InviteStatus {
  Valid,
  NotFound,
  Revoked,
  Expired,
  Exhausted,
};

const char* inviteErrorCode(InviteStatus s);

// Kullanıcının girdiği metni kanonik koda çevirir:
// "hg-ab3 d9x" → "AB3D9X". Türkçe küçük harf (ı/İ) tuzağına düşmez.
std::string normalizeCode(const std::string& raw);

InviteStatus checkInvite(const Invite& inv, int64_t now);

// Doğru kod girildiğinde kullanıcıya gösterilecek üyelik bilgileri.
struct Membership {
  std::string code;
  std::string invitedByUserId;
  std::string invitedByName;
  int64_t memberNumber = 0;    // kaçıncı üye (#42)
  int inviteQuota = 0;         // yeni üyenin dağıtabileceği davet sayısı
  bool earlyAccess = true;
  int64_t joinedAt = 0;

  json::Value toJson() const;
};

// Erken erişimde her yeni üyeye verilen davet hakkı.
constexpr int kDefaultInviteQuota = 3;
// Sistem tarafından üretilen kodların uzunluğu.
constexpr int kInviteCodeLength = 8;
// Kullanıcı kodlarının varsayılan geçerlilik süresi: 30 gün.
constexpr int64_t kInviteTtlMs = 30LL * 24 * 3600 * 1000;

}  // namespace hg::domain
