// Hanagram — mesajlaşma API'si
//
// Sohbetler iki kullanıcıdan deterministik türetilen bir kimlikte toplanır
// (domain/social/messaging.hpp). Okundu bilgisi sohbette tutulur; 1000 mesajlık
// bir sohbeti okundu işaretlemek tek yazma olmalıdır.
//
// Admin görünürlüğü için ayrı bir yol yoktur: mesajlar normal koleksiyonda durur
// ve admin.user zaten oradan okur.
#include <algorithm>

#include "../domain/social/messaging.hpp"
#include "../kernel/runtime.hpp"

namespace hg::kernel {

namespace {

using domain::Message;
using domain::Thread;

// Kullanıcıyı doğrular. Bulunamazsa ya da askıdaysa uygun hata kodunu döndürür;
// her şey yolundaysa boş dizge.
std::string checkUser(Store& store, const std::string& userId) {
  if (userId.empty()) return "ERR_USER_NOT_FOUND";
  const json::Value u = store.get(coll::kUsers, userId);
  if (u.isNull()) return "ERR_USER_NOT_FOUND";
  if (u["suspended"].asBool()) return "ERR_USER_SUSPENDED";
  return {};
}

Thread loadOrCreateThread(Store& store, const std::string& threadId,
                          const std::string& userA, const std::string& userB) {
  const json::Value existing = store.get(coll::kThreads, threadId);
  if (!existing.isNull()) return Thread::fromJson(existing);

  Thread t;
  t.id = threadId;
  // Katılımcılar kimliğe göre sıralı saklanır; okundu alanlarının (readA/readB)
  // hangi kullanıcıya ait olduğu böylece belirsizliğe düşmez.
  t.userA = userA < userB ? userA : userB;
  t.userB = userA < userB ? userB : userA;
  return t;
}

// Sohbet listesi öğesi: arayüzün ek sorgu yapmaması için karşı tarafın adı ve
// okunmamış bilgisi buraya gömülür.
json::Value threadListItem(Store& store, const Thread& t, const std::string& userId) {
  json::Value v = t.toJson();
  const std::string otherId = t.other(userId);
  const json::Value other = store.get(coll::kUsers, otherId);
  v.set("otherId", otherId);
  v.set("otherName", other.isNull() ? std::string("") : other["name"].asString());
  v.set("otherHandle", other.isNull() ? std::string("") : other["handle"].asString());
  v.set("unread", t.hasUnread(userId));
  return v;
}

}  // namespace

void registerMessagingApi(Runtime& rt) {
  // ——— Mesaj gönder ———
  rt.registerMethod("message.send", [](Context& ctx, const json::Value& p) {
    const std::string fromId = p["fromId"].asString();
    const std::string toId = p["toId"].asString();

    if (!fromId.empty() && fromId == toId) {
      return json::fail("ERR_SELF_MESSAGE", "message.pick_other");
    }

    std::string text;
    if (!domain::sanitizeMessageText(p["text"].asString(), text)) {
      return json::fail("ERR_MESSAGE_EMPTY", "message.type_something");
    }

    if (const std::string err = checkUser(ctx.store, fromId); !err.empty()) {
      return json::fail(err, "message.sender");
    }
    if (const std::string err = checkUser(ctx.store, toId); !err.empty()) {
      // Alıcının askıda olması da gönderimi engeller: askıdaki hesap
      // mesaj alamamalı, aksi halde moderasyon kararı delinmiş olur.
      return json::fail(err, "message.recipient");
    }

    const std::string threadId = domain::threadIdFor(fromId, toId);
    if (threadId.empty()) {
      return json::fail("ERR_SELF_MESSAGE", "message.pick_other");
    }

    const int64_t now = ctx.clock.now();

    Message m;
    m.id = ctx.ids.next(now);
    m.threadId = threadId;
    m.fromId = fromId;
    m.toId = toId;
    m.text = text;
    m.at = now;
    ctx.store.put(coll::kMessages, m.id, m.toJson());

    Thread t = loadOrCreateThread(ctx.store, threadId, fromId, toId);
    t.lastText = text;
    t.lastFromId = fromId;
    t.lastAt = now;
    t.messageCount += 1;
    // Gönderen kendi mesajını okumuş sayılır.
    if (fromId == t.userA) {
      t.readA = now;
    } else {
      t.readB = now;
    }
    // Sıralama için ikincil anahtar: aynı milisaniyede iki farklı sohbete mesaj
    // gidince lastAt eşit kalır ve liste sırası belirsizleşirdi. Mesaj kimlikleri
    // monoton arttığı için sıralamayı bu alan kesinleştirir.
    json::Value threadDoc = t.toJson();
    threadDoc.set("lastMessageId", m.id);
    ctx.store.put(coll::kThreads, threadId, threadDoc);

    ctx.bus.emit("message.sent", m.toJson());

    json::Value data = json::Value::obj();
    data.set("message", m.toJson());
    data.set("thread", t.toJson());
    return json::ok(data);
  });

  // ——— Sohbet listesi ———
  rt.registerMethod("message.threads", [](Context& ctx, const json::Value& p) {
    const std::string userId = p["userId"].asString();
    if (userId.empty()) return json::fail("ERR_USER_NOT_FOUND", "message.login");

    auto rows = ctx.store.where(coll::kThreads, [&](const json::Value& v) {
      return v["userA"].asString() == userId || v["userB"].asString() == userId;
    });

    // En son yazışılan başta: sohbet listesinin doğal sırası budur.
    std::sort(rows.begin(), rows.end(), [](const Record& a, const Record& b) {
      const int64_t at = a.data["lastAt"].asInt();
      const int64_t bt = b.data["lastAt"].asInt();
      if (at != bt) return at > bt;
      return a.data["lastMessageId"].asString() > b.data["lastMessageId"].asString();
    });

    json::Value arr = json::Value::arr();
    for (const auto& r : rows) {
      arr.push(threadListItem(ctx.store, Thread::fromJson(r.data), userId));
    }

    json::Value data = json::Value::obj();
    data.set("threads", arr);
    return json::ok(data);
  });

  // ——— Mesaj geçmişi ———
  rt.registerMethod("message.history", [](Context& ctx, const json::Value& p) {
    const std::string userId = p["userId"].asString();
    const std::string threadId = p["threadId"].asString();

    const json::Value raw = ctx.store.get(coll::kThreads, threadId);
    if (raw.isNull()) return json::fail("ERR_THREAD_NOT_FOUND", "message.threads");

    const Thread t = Thread::fromJson(raw);
    // Gizlilik sınırı: sohbet yalnızca iki katılımcısına açıktır.
    if (userId != t.userA && userId != t.userB) {
      return json::fail("ERR_FORBIDDEN", "message.threads");
    }

    const int64_t requested = p["limit"].asInt(domain::kDefaultHistoryLimit);
    const size_t limit = requested > 0
                             ? static_cast<size_t>(requested)
                             : static_cast<size_t>(domain::kDefaultHistoryLimit);

    auto rows = ctx.store.where(coll::kMessages, [&](const json::Value& v) {
      return v["threadId"].asString() == threadId;
    });
    // Kimlikler zaman öncelikli üretildiği için kimliğe göre sıralamak
    // gönderim sırasını verir; ayrı bir zaman indeksine gerek yoktur.
    std::sort(rows.begin(), rows.end(),
              [](const Record& a, const Record& b) { return a.id < b.id; });

    // Limit son mesajlara uygulanır, ama sonuç eskiden yeniye döner:
    // sohbet ekranı yukarı doğru okunacak şekilde çizilir.
    const size_t start = rows.size() > limit ? rows.size() - limit : 0;

    json::Value arr = json::Value::arr();
    for (size_t i = start; i < rows.size(); i++) arr.push(rows[i].data);

    json::Value data = json::Value::obj();
    data.set("messages", arr);
    data.set("thread", threadListItem(ctx.store, t, userId));
    return json::ok(data);
  });

  // ——— Okundu işaretle ———
  rt.registerMethod("message.read", [](Context& ctx, const json::Value& p) {
    const std::string userId = p["userId"].asString();
    const std::string threadId = p["threadId"].asString();

    const json::Value raw = ctx.store.get(coll::kThreads, threadId);
    if (raw.isNull()) return json::fail("ERR_THREAD_NOT_FOUND", "message.threads");

    Thread t = Thread::fromJson(raw);
    if (userId != t.userA && userId != t.userB) {
      return json::fail("ERR_FORBIDDEN", "message.threads");
    }

    const int64_t now = ctx.clock.now();
    if (userId == t.userA) {
      t.readA = now;
    } else {
      t.readB = now;
    }
    // lastMessageId Thread yapısının parçası değil; ham kayıttan taşınır ki
    // sohbet listesi sıralaması okundu işaretlemesinden sonra bozulmasın.
    json::Value doc = t.toJson();
    if (raw.has("lastMessageId")) doc.set("lastMessageId", raw["lastMessageId"]);
    ctx.store.put(coll::kThreads, threadId, doc);

    return json::ok(json::Value::obj());
  });
}

}  // namespace hg::kernel
