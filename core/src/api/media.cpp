// Hanagram — medya API'si
//
// Medya kayıtlarını yönetir. Gerçek dosya yükleme platformdadır (Flutter);
// burada yalnızca meta veri kaydı tutulur. Platform dosyayı yükler, ardından
// `media.register` ile çekirdeğe bildirir.
#include <algorithm>

#include "../domain/media/media.hpp"
#include "../kernel/runtime.hpp"

namespace hg::kernel {

namespace {

using domain::MediaItem;
using domain::MediaType;

std::vector<MediaItem> mediaOf(Store& store, const std::string& ownerId) {
  std::vector<MediaItem> out;
  for (const Record& r : store.where(coll::kMedia,
                                     [&](const json::Value& v) {
                                       return v["ownerId"].asString() == ownerId;
                                     })) {
    out.push_back(MediaItem::fromJson(r.data));
  }
  return out;
}

}  // namespace

void registerMediaApi(Runtime& rt) {
  // ——— Medya kaydı (platform yükledikten sonra çağırır) ———
  rt.registerMethod("media.register", [](Context& ctx, const json::Value& p) {
    const std::string ownerId = p["ownerId"].asString();
    if (ownerId.empty()) return json::fail("ERR_OWNER_REQUIRED");

    const std::string filePath = p["filePath"].asString();
    if (filePath.empty()) return json::fail("ERR_FILE_PATH_REQUIRED");

    const std::string mime = p["mimeType"].asString();
    if (!domain::isAllowedMimeType(mime)) return json::fail("ERR_INVALID_MIME");

    const MediaType type = domain::mediaTypeFromString(p["type"].asString());
    const int64_t fileSize = p["fileSize"].asInt();

    if (type == MediaType::kPhoto && fileSize > domain::kMaxPhotoSizeBytes) {
      return json::fail("ERR_FILE_TOO_LARGE");
    }
    if (type == MediaType::kVideo) {
      if (fileSize > domain::kMaxVideoSizeBytes) return json::fail("ERR_FILE_TOO_LARGE");
      const int64_t dur = p["durationMs"].asInt();
      if (dur > domain::kMaxVideoDurationMs) return json::fail("ERR_VIDEO_TOO_LONG");
    }

    MediaItem m;
    m.id = ctx.ids.next(ctx.clock.now());
    m.ownerId = ownerId;
    m.type = type;
    m.filePath = filePath;
    m.thumbnailPath = p["thumbnailPath"].asString();
    m.mimeType = mime;
    m.fileSize = fileSize;
    m.width = static_cast<int32_t>(p["width"].asInt());
    m.height = static_cast<int32_t>(p["height"].asInt());
    m.durationMs = p["durationMs"].asInt();
    m.caption = domain::sanitizeMediaCaption(p["caption"].asString());
    m.createdAt = ctx.clock.now();

    ctx.store.put(coll::kMedia, m.id, m.toJson());
    return json::ok(m.toJson());
  });

  // ——— Medya listesi ———
  rt.registerMethod("media.list", [](Context& ctx, const json::Value& p) {
    const std::string ownerId = p["ownerId"].asString();
    if (ownerId.empty()) return json::fail("ERR_OWNER_REQUIRED");

    std::vector<MediaItem> list = mediaOf(ctx.store, ownerId);
    std::sort(list.begin(), list.end(),
              [](const MediaItem& a, const MediaItem& b) { return a.createdAt > b.createdAt; });

    json::Value items = json::Value::arr();
    for (const MediaItem& m : list) items.push(m.toJson());

    json::Value d = json::Value::obj();
    d.set("items", items);
    d.set("total", static_cast<int64_t>(list.size()));
    return json::ok(d);
  });

  // ——— Medya sil ———
  rt.registerMethod("media.delete", [](Context& ctx, const json::Value& p) {
    const std::string ownerId = p["ownerId"].asString();
    if (ownerId.empty()) return json::fail("ERR_OWNER_REQUIRED");

    const std::string mediaId = p["mediaId"].asString();
    const json::Value v = ctx.store.get(coll::kMedia, mediaId);
    if (v.isNull()) return json::fail("ERR_MEDIA_NOT_FOUND");

    MediaItem m = MediaItem::fromJson(v);
    if (m.ownerId != ownerId) return json::fail("ERR_MEDIA_NOT_FOUND");

    ctx.store.remove(coll::kMedia, mediaId);
    return json::ok(json::Value::obj());
  });
}

}  // namespace hg::kernel
