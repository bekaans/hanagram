// Medya alanı testleri
#include "domain/media/media.hpp"
#include "test.hpp"

using namespace hg;
using namespace hg::domain;

namespace {

MediaItem samplePhoto() {
  MediaItem m;
  m.id = "m1";
  m.ownerId = "u1";
  m.type = MediaType::kPhoto;
  m.filePath = "media/u1/photo1.jpg";
  m.thumbnailPath = "media/u1/thumb1.jpg";
  m.mimeType = "image/jpeg";
  m.fileSize = 2048000;
  m.width = 1920;
  m.height = 1080;
  m.durationMs = 0;
  m.caption = "Güzel bir gün";
  m.createdAt = 1000;
  return m;
}

MediaItem sampleVideo() {
  MediaItem m;
  m.id = "m2";
  m.ownerId = "u1";
  m.type = MediaType::kVideo;
  m.filePath = "media/u1/video1.mp4";
  m.thumbnailPath = "";
  m.mimeType = "video/mp4";
  m.fileSize = 50000000;
  m.width = 1280;
  m.height = 720;
  m.durationMs = 30000;
  m.caption = "";
  m.createdAt = 2000;
  return m;
}

}  // namespace

// ── Tür dönüşümü ──

TEST(mediaType_gidis_donus) {
  CHECK_EQ(std::string(mediaTypeToString(MediaType::kPhoto)), std::string("photo"));
  CHECK_EQ(std::string(mediaTypeToString(MediaType::kVideo)), std::string("video"));
}

TEST(mediaType_fromString) {
  CHECK_EQ(mediaTypeFromString("photo"), MediaType::kPhoto);
  CHECK_EQ(mediaTypeFromString("video"), MediaType::kVideo);
  CHECK_EQ(mediaTypeFromString("bogus"), MediaType::kPhoto);
}

// ── MIME doğrulama ──

TEST(isAllowedMimeType_gecerli) {
  CHECK(isAllowedMimeType("image/jpeg"));
  CHECK(isAllowedMimeType("image/png"));
  CHECK(isAllowedMimeType("image/webp"));
  CHECK(isAllowedMimeType("image/gif"));
  CHECK(isAllowedMimeType("video/mp4"));
  CHECK(isAllowedMimeType("video/quicktime"));
}

TEST(isAllowedMimeType_gecersiz) {
  CHECK(!isAllowedMimeType(""));
  CHECK(!isAllowedMimeType("text/plain"));
  CHECK(!isAllowedMimeType("application/pdf"));
  CHECK(!isAllowedMimeType("image/bmp"));
}

// ── Açıklama doğrulama ──

TEST(sanitizeMediaCaption_normal) {
  CHECK_EQ(sanitizeMediaCaption("Güzel bir gün"), std::string("Güzel bir gün"));
}

TEST(sanitizeMediaCaption_bos) {
  CHECK(sanitizeMediaCaption("").empty());
  CHECK(sanitizeMediaCaption("   ").empty());
}

TEST(sanitizeMediaCaption_basi_sondaki_bosluk) {
  CHECK_EQ(sanitizeMediaCaption("  Merhaba  "), std::string("Merhaba"));
}

// ── JSON dönüşümü ──

TEST(mediaJson_photo_roundtrip) {
  MediaItem m = samplePhoto();
  json::Value j = m.toJson();
  MediaItem m2 = MediaItem::fromJson(j);
  CHECK_EQ(m2.id, m.id);
  CHECK_EQ(m2.ownerId, m.ownerId);
  CHECK_EQ(m2.type, m.type);
  CHECK_EQ(m2.filePath, m.filePath);
  CHECK_EQ(m2.mimeType, m.mimeType);
  CHECK_EQ(m2.fileSize, m.fileSize);
  CHECK_EQ(m2.width, m.width);
  CHECK_EQ(m2.height, m.height);
  CHECK_EQ(m2.caption, m.caption);
}

TEST(mediaJson_video_roundtrip) {
  MediaItem m = sampleVideo();
  json::Value j = m.toJson();
  MediaItem m2 = MediaItem::fromJson(j);
  CHECK_EQ(m2.type, MediaType::kVideo);
  CHECK_EQ(m2.durationMs, m.durationMs);
  CHECK(m2.thumbnailPath.empty());
}
