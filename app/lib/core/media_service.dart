// Hanagram — medya yükleme servisi
//
// Tek sorumluluk: avatar ve içerik medyası yükleme (Supabase Storage).
import 'web_compat.dart';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class MediaService {
  MediaService._();

  static SupabaseClient get _storage => SupabaseService.client;

  /// Profil resmi yükle — sıkıştır + Supabase Storage'a kaydet.
  /// Public URL döndürür.
  static Future<String?> uploadAvatar(File imageFile, String userId) async {
    try {
      // Görseli oku ve sıkıştır
      final bytes = await imageFile.readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Maksimum 800px'e küçült
      if (decoded.width > 800 || decoded.height > 800) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? 800 : null,
          height: decoded.height >= decoded.width ? 800 : null,
        );
      }

      // JPEG olarak sıkıştır (quality: 85)
      final compressed = img.encodeJpg(decoded, quality: 85);
      final fileName = '$userId.jpg';

      // Eski avatar varsa sil
      try {
        await _storage.storage.from('avatars').remove([fileName]);
      } catch (_) {}

      // Yükle
      await _storage.storage.from('avatars').uploadBinary(
            fileName,
            compressed,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Public URL al
      final url = _storage.storage.from('avatars').getPublicUrl(fileName);
      return url;
    } catch (_) {
      return null;
    }
  }

  /// İçerik medyası yükle (fotoğraf veya video).
  /// Public URL döndürür.
  static Future<String?> uploadMedia(
    File file,
    String userId, {
    String type = 'image',
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(file.path);
      final fileName = '$userId/$timestamp$ext';
      final bucket = type == 'video' ? 'media' : 'media';

      if (type == 'image') {
        // Fotoğrafı sıkıştır
        final bytes = await file.readAsBytes();
        var decoded = img.decodeImage(bytes);
        if (decoded == null) return null;

        if (decoded.width > 1200 || decoded.height > 1200) {
          decoded = img.copyResize(
            decoded,
            width: decoded.width > decoded.height ? 1200 : null,
            height: decoded.height >= decoded.width ? 1200 : null,
          );
        }

        final compressed = img.encodeJpg(decoded, quality: 80);
        await _storage.storage.from(bucket).uploadBinary(
              fileName,
              compressed,
              fileOptions: const FileOptions(
                upsert: false,
                contentType: 'image/jpeg',
              ),
            );
      } else {
        // Video — doğrudan yükle (max 50MB kontrolü caller'da yapılmalı)
        final bytes = await file.readAsBytes();
        await _storage.storage.from(bucket).uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: 'video/mp4',
              ),
            );
      }

      return _storage.storage.from(bucket).getPublicUrl(fileName);
    } catch (_) {
      return null;
    }
  }

  /// Public URL getir (path'ten).
  static String getPublicUrl(String bucket, String path) {
    return _storage.storage.from(bucket).getPublicUrl(path);
  }
}
