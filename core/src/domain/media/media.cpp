// Hanagram — medya alanı implementasyonu
#include "media.hpp"

namespace hg::domain {

const char* mediaTypeToString(MediaType t) {
  switch (t) {
    case MediaType::kPhoto: return "photo";
    case MediaType::kVideo: return "video";
  }
  return "photo";
}

MediaType mediaTypeFromString(const std::string& s) {
  if (s == "video") return MediaType::kVideo;
  return MediaType::kPhoto;
}

bool isAllowedMimeType(const std::string& mime) {
  return mime == "image/jpeg" || mime == "image/png" ||
         mime == "image/webp" || mime == "image/gif" ||
         mime == "video/mp4"  || mime == "video/quicktime";
}

json::Value MediaItem::toJson() const {
  json::Value j = json::Value::obj();
  j.set("id", id);
  j.set("ownerId", ownerId);
  j.set("type", mediaTypeToString(type));
  j.set("filePath", filePath);
  j.set("thumbnailPath", thumbnailPath);
  j.set("mimeType", mimeType);
  j.set("fileSize", fileSize);
  j.set("width", static_cast<int64_t>(width));
  j.set("height", static_cast<int64_t>(height));
  j.set("durationMs", durationMs);
  j.set("caption", caption);
  j.set("createdAt", createdAt);
  return j;
}

MediaItem MediaItem::fromJson(const json::Value& v) {
  MediaItem m;
  m.id = v["id"].asString();
  m.ownerId = v["ownerId"].asString();
  m.type = mediaTypeFromString(v["type"].asString());
  m.filePath = v["filePath"].asString();
  m.thumbnailPath = v["thumbnailPath"].asString();
  m.mimeType = v["mimeType"].asString();
  m.fileSize = v["fileSize"].asInt();
  m.width = static_cast<int32_t>(v["width"].asInt());
  m.height = static_cast<int32_t>(v["height"].asInt());
  m.durationMs = v["durationMs"].asInt();
  m.caption = v["caption"].asString();
  m.createdAt = v["createdAt"].asInt();
  return m;
}

std::string sanitizeMediaCaption(const std::string& raw) {
  size_t start = 0;
  while (start < raw.size() && static_cast<unsigned char>(raw[start]) <= 0x20) ++start;
  size_t end = raw.size();
  while (end > start && static_cast<unsigned char>(raw[end - 1]) <= 0x20) --end;
  std::string trimmed = raw.substr(start, end - start);

  size_t byteLen = 0;
  size_t charCount = 0;
  while (byteLen < trimmed.size() && charCount < kMaxMediaCaptionLength) {
    unsigned char c = static_cast<unsigned char>(trimmed[byteLen]);
    size_t charBytes = 1;
    if ((c & 0x80) != 0) {
      if ((c & 0xE0) == 0xC0) charBytes = 2;
      else if ((c & 0xF0) == 0xE0) charBytes = 3;
      else if ((c & 0xF8) == 0xF0) charBytes = 4;
    }
    if (byteLen + charBytes > trimmed.size()) break;
    byteLen += charBytes;
    ++charCount;
  }
  while (byteLen > 0 && (static_cast<unsigned char>(trimmed[byteLen]) & 0xC0) == 0x80) --byteLen;
  return trimmed.substr(0, byteLen);
}

}  // namespace hg::domain
