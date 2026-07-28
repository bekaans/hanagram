// Hanagram — medya alanı (SÖZLEŞME)
//
// Fotoğraf ve video meta verilerini tutar. Gerçek dosya I/O platformdadır
// (Flutter image_picker / video_picker); çekirdek yalnızca meta veriyi depolar
// ve medya kayıtlarını yönetir.
//
// Tasarım kararları:
//  - `ownerId` kullanıcının kendi medyası için userId, işletme medyası için
//    businessId tutar. Tek alanla hem profil fotoğrafı hem ürün fotoğrafı kapsanır.
//  - `filePath` veri dizinine göreli yoldur (mutlak değil).
//  - `thumbnailPath` boşsa platform küçük resim üretmemiştir.
//  - Dosya boyutu bayt cinsinden; video için süre ms cinsinden tutulur.
#pragma once

#include <cstdint>
#include <string>

#include "../../util/json.hpp"

namespace hg::domain {

enum class MediaType { kPhoto, kVideo };

struct MediaItem {
  std::string id;
  std::string ownerId;
  MediaType type = MediaType::kPhoto;
  std::string filePath;
  std::string thumbnailPath;
  std::string mimeType;
  int64_t fileSize = 0;
  int32_t width = 0;
  int32_t height = 0;
  int64_t durationMs = 0;  // yalnızca video
  std::string caption;
  int64_t createdAt = 0;

  json::Value toJson() const;
  static MediaItem fromJson(const json::Value& v);
};

const char* mediaTypeToString(MediaType t);
MediaType mediaTypeFromString(const std::string& s);

/// Medya dosyası MIME türünü doğrular. İzin verilenler: image/jpeg,
/// image/png, image/webp, image/gif, video/mp4, video/quicktime.
bool isAllowedMimeType(const std::string& mime);

/// Medya açıklamasını doğrular ve kırpılmış hâlini verir.
std::string sanitizeMediaCaption(const std::string& raw);

constexpr size_t kMaxMediaCaptionLength = 300;
constexpr int64_t kMaxPhotoSizeBytes = 10 * 1024 * 1024;   // 10 MB
constexpr int64_t kMaxVideoSizeBytes = 100 * 1024 * 1024;  // 100 MB
constexpr int64_t kMaxVideoDurationMs = 5 * 60 * 1000;     // 5 dakika

}  // namespace hg::domain
