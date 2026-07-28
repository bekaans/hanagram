// Hanagram — mesajlaşma alanı (SÖZLEŞME — değiştirilemez)
//
// Bu başlık dosyası bir sözleşmedir. Uygulama (api/messaging.cpp) buna uyar;
// imzalar, alan adları ve kurallar değiştirilmez.
//
// Tasarım kararları:
//  - Sohbet kimliği iki kullanıcıdan DETERMİNİSTİK üretilir. Böylece aynı çift
//    her zaman aynı sohbete düşer; "aynı kişiyle iki sohbet" hatası imkânsız olur.
//  - Okundu bilgisi mesajda değil, sohbette kullanıcı başına tutulur: 1000 mesajlık
//    sohbeti okundu işaretlemek 1000 yazma yapmamalı.
//  - Admin görünürlüğü ayrı bir yol değildir; mesajlar normal koleksiyonda durur ve
//    admin.user zaten okur.
#pragma once

#include <string>
#include <vector>

#include "../../util/json.hpp"

namespace hg::domain {

struct Message {
  std::string id;
  std::string threadId;
  std::string fromId;
  std::string toId;
  std::string text;
  int64_t at = 0;

  json::Value toJson() const;
  static Message fromJson(const json::Value& v);
};

struct Thread {
  std::string id;
  std::string userA;       // her zaman alfabetik olarak küçük olan
  std::string userB;
  std::string lastText;
  std::string lastFromId;
  int64_t lastAt = 0;
  int64_t messageCount = 0;
  // Kullanıcı başına en son okunan zaman damgası.
  int64_t readA = 0;
  int64_t readB = 0;

  /// Karşı tarafın kimliği. userId katılımcı değilse boş dizge.
  std::string other(const std::string& userId) const;

  /// Bu kullanıcının okumadığı mesaj var mı.
  bool hasUnread(const std::string& userId) const;

  json::Value toJson() const;
  static Thread fromJson(const json::Value& v);
};

/// İki kullanıcıdan deterministik sohbet kimliği üretir.
/// Sıra önemsizdir: threadId(a,b) == threadId(b,a).
/// Aynı kullanıcı iki kez verilirse boş dizge döner (kendine mesaj yasak).
std::string threadIdFor(const std::string& userA, const std::string& userB);

/// Mesaj metnini doğrular ve kırpar.
/// Kurallar: baştaki/sondaki boşluklar atılır, boş metin geçersizdir,
/// en fazla kMaxMessageLength karakter (fazlası kırpılır, hata değildir).
/// Geçersizse false döner ve out'a dokunulmaz.
bool sanitizeMessageText(const std::string& raw, std::string& out);

constexpr size_t kMaxMessageLength = 2000;
constexpr int kDefaultHistoryLimit = 50;

}  // namespace hg::domain
