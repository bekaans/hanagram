// Hanagram — sosyal API: gönderi, akış, sinyal
//
// feed.get burada UI'ye hazır bir liste döner. Sıralama kararı tamamen çekirdekte;
// ekran hiçbir sıralama mantığı taşımaz (docs/01-mimari.md §7).
#include "../algo/interest.hpp"
#include "../kernel/runtime.hpp"

namespace hg::kernel {

namespace {

algo::InterestProfile loadProfile(Store& s, const std::string& userId) {
  json::Value v = s.get(coll::kProfiles, userId);
  return v.isNull() ? algo::InterestProfile{} : algo::InterestProfile::fromJson(v);
}

std::vector<std::string> topicsOf(const json::Value& post) {
  std::vector<std::string> out;
  for (const auto& t : post["topics"].asArray()) out.push_back(t.asString());
  return out;
}

json::Value postPublic(Store& s, const json::Value& post, const algo::ScoredItem* si) {
  json::Value author = s.get(coll::kUsers, post["authorId"].asString());

  json::Value v = json::Value::obj();
  v.set("id", post["id"]);
  v.set("authorId", post["authorId"]);
  v.set("authorName", author.isNull() ? std::string("") : author["name"].asString());
  v.set("authorHandle", author.isNull() ? std::string("") : author["handle"].asString());
  v.set("mediaUri", post["mediaUri"]);
  v.set("kind", post["kind"]);
  v.set("caption", post["caption"]);
  v.set("topics", post["topics"]);
  v.set("likes", post["likes"]);
  v.set("commentCount", post["commentCount"]);
  v.set("createdAt", post["createdAt"]);
  v.set("sponsored", post["sponsored"]);

  if (si) {
    // Açıklanabilirlik: neden gösterildi. Admin panelinde okunur; uygulamada gizli.
    json::Value why = json::Value::obj();
    why.set("score", si->score);
    why.set("predicted", si->predicted);
    why.set("exploration", si->exploration);
    why.set("interest", si->parts.interest);
    why.set("freshness", si->parts.freshness);
    why.set("quality", si->parts.quality);
    why.set("affinity", si->parts.affinity);
    why.set("following", si->parts.following);
    v.set("_why", why);
  }
  return v;
}

}  // namespace

void registerSocialApi(Runtime& rt) {
  // ——— Gönderi oluştur ———
  rt.registerMethod("post.create", [](Context& ctx, const json::Value& p) {
    const std::string authorId = p["authorId"].asString();
    if (ctx.store.get(coll::kUsers, authorId).isNull()) {
      return json::fail("ERR_USER_NOT_FOUND");
    }
    const int64_t now = ctx.clock.now();
    const std::string id = ctx.ids.next(now);

    json::Value post = json::Value::obj();
    post.set("id", id);
    post.set("authorId", authorId);
    post.set("mediaUri", p["mediaUri"]);
    post.set("kind", p["kind"].asString().empty() ? std::string("image") : p["kind"].asString());
    post.set("caption", p["caption"]);
    post.set("topics", p.has("topics") ? p["topics"] : json::Value::arr());
    post.set("likes", 0);
    post.set("views", 0);
    post.set("commentCount", 0);
    post.set("shares", 0);
    post.set("createdAt", now);
    post.set("sponsored", p["sponsored"].asBool());
    post.set("bid", p["bid"].asNumber(0));
    post.set("removed", false);
    ctx.store.put(coll::kPosts, id, post);

    ctx.bus.emit(topics::kPostCreated, post);
    return json::ok(post);
  });

  // ——— AKIŞ — algoritmanın kalbi ———
  rt.registerMethod("feed.get", [](Context& ctx, const json::Value& p) {
    const std::string userId = p["userId"].asString();
    const std::string mode = p["mode"].asString().empty() ? "foryou" : p["mode"].asString();
    const int limit = static_cast<int>(p["limit"].asInt(20));
    const int64_t now = ctx.clock.now();

    algo::InterestProfile profile = loadProfile(ctx.store, userId);

    // Görülmüş öğeler — tekrar göstermemek için.
    json::Value seenDoc = ctx.store.get(coll::kSystem, "seen:" + userId);
    std::vector<std::string> seenIds;
    for (const auto& s : seenDoc["ids"].asArray()) seenIds.push_back(s.asString());
    auto wasSeen = [&](const std::string& id) {
      for (const auto& s : seenIds) if (s == id) return true;
      return false;
    };

    // Takip edilenler
    json::Value followDoc = ctx.store.get(coll::kSystem, "follows:" + userId);
    auto isFollowing = [&](const std::string& authorId) {
      for (const auto& f : followDoc["ids"].asArray()) {
        if (f.asString() == authorId) return true;
      }
      return false;
    };

    // Aday havuzu
    std::vector<algo::Candidate> pool;
    for (const auto& r : ctx.store.all(coll::kPosts)) {
      const json::Value& post = r.data;
      if (post["removed"].asBool()) continue;
      if (post["authorId"].asString() == userId) continue;  // kendi gönderin akışta yok

      algo::Candidate c;
      c.id = post["id"].asString();
      c.authorId = post["authorId"].asString();
      c.topics = topicsOf(post);
      c.createdAt = post["createdAt"].asInt();
      c.views = post["views"].asInt();
      c.likes = post["likes"].asInt();
      c.comments = post["commentCount"].asInt();
      c.shares = post["shares"].asInt();
      c.following = isFollowing(c.authorId);
      c.seen = wasSeen(c.id);
      c.sponsored = post["sponsored"].asBool();
      c.bid = post["bid"].asNumber(0);
      pool.push_back(c);
    }

    algo::RankOptions opt;
    opt.limit = limit;
    opt.followingOnly = (mode == "following");
    if (opt.followingOnly) opt.adEvery = 0;  // takip akışında reklam yok

    const auto ranked = ctx.ranker.rank(pool, profile, now, opt);

    json::Value items = json::Value::arr();
    for (const auto& si : ranked) {
      json::Value post = ctx.store.get(coll::kPosts, si.id);
      if (post.isNull()) continue;
      items.push(postPublic(ctx.store, post, &si));

      // Gösterim kaydı — öğrenme bunun sonucunu bekleyecek.
      algo::Impression imp;
      imp.userId = userId;
      imp.itemId = si.id;
      imp.parts = si.parts;
      imp.predicted = si.predicted;
      imp.exploration = si.exploration;
      imp.shownAt = now;
      ctx.learner.recordImpression(imp);
    }

    json::Value v = json::Value::obj();
    v.set("items", items);
    v.set("mode", mode);
    v.set("profileConfidence", profile.confidence());
    return json::ok(v);
  });

  // ——— Sinyal: öğrenmenin girdisi ———
  rt.registerMethod("signal.record", [](Context& ctx, const json::Value& p) {
    const std::string userId = p["userId"].asString();
    const std::string itemId = p["itemId"].asString();
    const std::string kindName = p["kind"].asString();

    algo::SignalKind kind;
    if (!algo::signalFromName(kindName, kind)) {
      return json::fail("ERR_SIGNAL_UNKNOWN", kindName);
    }

    const int64_t now = ctx.clock.now();
    json::Value post = ctx.store.get(coll::kPosts, itemId);

    algo::Signal s;
    s.userId = userId;
    s.itemId = itemId;
    s.authorId = post.isNull() ? p["authorId"].asString() : post["authorId"].asString();
    s.topics = post.isNull() ? std::vector<std::string>{} : topicsOf(post);
    s.kind = kind;
    s.dwellMs = p["dwellMs"].asInt();
    s.at = now;

    // 1) Kullanıcı profilini güncelle
    algo::InterestProfile profile = loadProfile(ctx.store, userId);
    profile.apply(s, now);
    ctx.store.put(coll::kProfiles, userId, profile.toJson());

    // 2) Öğrenme katmanına sonucu bildir
    const bool engaged =
        kind == algo::SignalKind::Like || kind == algo::SignalKind::Comment ||
        kind == algo::SignalKind::Save || kind == algo::SignalKind::Share ||
        kind == algo::SignalKind::Follow || kind == algo::SignalKind::ProductTap ||
        (kind == algo::SignalKind::Dwell && s.dwellMs >= 5000);
    ctx.learner.recordOutcome(userId, itemId, engaged, s.dwellMs);

    // 3) İçerik sayaçlarını güncelle
    if (!post.isNull()) {
      auto bump = [&](const char* field, int64_t by) {
        post.set(field, post[field].asInt() + by);
      };
      switch (kind) {
        case algo::SignalKind::View: bump("views", 1); break;
        case algo::SignalKind::Like: bump("likes", 1); break;
        case algo::SignalKind::Comment: bump("commentCount", 1); break;
        case algo::SignalKind::Share: bump("shares", 1); break;
        default: break;
      }
      ctx.store.put(coll::kPosts, itemId, post);
    }

    // 4) Görülmüş listesi (son 200)
    json::Value seenDoc = ctx.store.get(coll::kSystem, "seen:" + userId);
    json::Value ids = seenDoc.has("ids") ? seenDoc["ids"] : json::Value::arr();
    if (kind == algo::SignalKind::View || kind == algo::SignalKind::Skip) {
      json::Value next = json::Value::arr();
      next.push(itemId);
      int n = 1;
      for (const auto& s2 : ids.asArray()) {
        if (s2.asString() == itemId) continue;
        if (++n > 200) break;
        next.push(s2);
      }
      json::Value doc = json::Value::obj();
      doc.set("ids", next);
      ctx.store.put(coll::kSystem, "seen:" + userId, doc);
    }

    // 5) Takip
    if (kind == algo::SignalKind::Follow && !s.authorId.empty()) {
      json::Value fdoc = ctx.store.get(coll::kSystem, "follows:" + userId);
      json::Value fids = fdoc.has("ids") ? fdoc["ids"] : json::Value::arr();
      bool already = false;
      for (const auto& f : fids.asArray()) {
        if (f.asString() == s.authorId) { already = true; break; }
      }
      if (!already) {
        fids.push(s.authorId);
        json::Value doc = json::Value::obj();
        doc.set("ids", fids);
        ctx.store.put(coll::kSystem, "follows:" + userId, doc);
      }
    }

    // Ham sinyal saklanır — admin ve ileride toplu yeniden eğitim için.
    json::Value rec = json::Value::obj();
    rec.set("userId", userId);
    rec.set("itemId", itemId);
    rec.set("kind", kindName);
    rec.set("dwellMs", s.dwellMs);
    rec.set("at", now);
    ctx.store.put(coll::kSignals, ctx.ids.next(now), rec);

    ctx.bus.emit(topics::kSignalRecorded, rec);

    json::Value v = json::Value::obj();
    v.set("recorded", true);
    v.set("profileConfidence", profile.confidence());
    return json::ok(v);
  });

  // ——— Keşfet: ilgi alanına göre içerik + ürün ———
  rt.registerMethod("discover.get", [](Context& ctx, const json::Value& p) {
    const std::string userId = p["userId"].asString();
    const std::string query = p["query"].asString();
    const int64_t now = ctx.clock.now();
    algo::InterestProfile profile = loadProfile(ctx.store, userId);

    std::vector<algo::Candidate> pool;
    for (const auto& r : ctx.store.all(coll::kPosts)) {
      const json::Value& post = r.data;
      if (post["removed"].asBool()) continue;
      if (!query.empty()) {
        const std::string hay = post["caption"].asString();
        if (hay.find(query) == std::string::npos) continue;
      }
      algo::Candidate c;
      c.id = post["id"].asString();
      c.authorId = post["authorId"].asString();
      c.topics = topicsOf(post);
      c.createdAt = post["createdAt"].asInt();
      c.views = post["views"].asInt();
      c.likes = post["likes"].asInt();
      c.comments = post["commentCount"].asInt();
      c.shares = post["shares"].asInt();
      c.sponsored = post["sponsored"].asBool();
      c.bid = post["bid"].asNumber(0);
      pool.push_back(c);
    }

    algo::RankOptions opt;
    opt.limit = static_cast<int>(p["limit"].asInt(30));
    opt.maxPerAuthor = 3;
    opt.adEvery = 9;
    opt.exploreBase = 0.25;  // keşfet daha cesur

    const auto ranked = ctx.ranker.rank(pool, profile, now, opt);
    json::Value items = json::Value::arr();
    for (const auto& si : ranked) {
      json::Value post = ctx.store.get(coll::kPosts, si.id);
      if (!post.isNull()) items.push(postPublic(ctx.store, post, &si));
    }

    // Kullanıcının en güçlü ilgi alanları — pazaryeri eşleştirmesi buna göre.
    json::Value interests = json::Value::arr();
    for (const auto& [topic, w] : profile.topics()) {
      if (w > 0.05) {
        json::Value t = json::Value::obj();
        t.set("topic", topic);
        t.set("weight", w);
        interests.push(t);
      }
    }

    json::Value v = json::Value::obj();
    v.set("items", items);
    v.set("interests", interests);
    return json::ok(v);
  });
}

}  // namespace hg::kernel
