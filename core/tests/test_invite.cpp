#include "domain/identity/invite.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::domain;

TEST(davet_kod_normalizasyonu) {
  CHECK_EQ(normalizeCode("ab3 d9x"), std::string("AB3D9X"));
  CHECK_EQ(normalizeCode("  AB3D9X  "), std::string("AB3D9X"));
  CHECK_EQ(normalizeCode("ab3-d9x"), std::string("AB3D9X"));
}

TEST(davet_marka_oneki_ayiklanmaz) {
  // Kod alfabesinde H ve G var; "HG" ile başlayan gerçek kodlar bozulmamalı.
  CHECK_EQ(normalizeCode("hg2k7m9p"), std::string("HG2K7M9P"));
}

TEST(davet_karisan_karakterler_duzeltilir) {
  // Kod alfabesinde O, I, L yok. Kullanıcı O yazdıysa 0, I/L yazdıysa 1 kastetmiştir.
  CHECK_EQ(normalizeCode("2OI L23"), std::string("201123"));
  CHECK_EQ(normalizeCode("olive"), std::string("011VE"));  // O→0, L→1, I→1
}

TEST(davet_gecerlilik_durumlari) {
  const int64_t now = 1'700'000'000'000;
  Invite inv;
  inv.code = "ABC12345";
  inv.maxUses = 1;
  inv.createdAt = now;

  CHECK(checkInvite(inv, now) == InviteStatus::Valid);

  inv.usedCount = 1;
  CHECK(checkInvite(inv, now) == InviteStatus::Exhausted);

  inv.usedCount = 0;
  inv.expiresAt = now - 1;
  CHECK(checkInvite(inv, now) == InviteStatus::Expired);

  inv.expiresAt = 0;
  inv.revoked = true;
  CHECK(checkInvite(inv, now) == InviteStatus::Revoked);
}

TEST(davet_bos_kod_bulunamadi) {
  Invite bos;
  CHECK(checkInvite(bos, 1) == InviteStatus::NotFound);
  CHECK_EQ(std::string(inviteErrorCode(InviteStatus::NotFound)),
           std::string("ERR_INVITE_INVALID"));
}

TEST(davet_json_gidis_donus) {
  Invite inv;
  inv.code = "TESTCODE";
  inv.ownerId = "u1";
  inv.maxUses = 3;
  inv.usedCount = 1;
  inv.redeemedBy = {"u2"};

  Invite back = Invite::fromJson(inv.toJson());
  CHECK_EQ(back.code, inv.code);
  CHECK_EQ(back.maxUses, 3);
  CHECK_EQ(back.usedCount, 1);
  CHECK_EQ(back.redeemedBy.size(), size_t(1));
}
