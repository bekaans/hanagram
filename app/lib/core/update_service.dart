// Hanagram — otomatik güncelleme servisi (5 platform)
//
// Tek sorumluluk: yeni versiyon kontrolü + indirme bilgisi.
// Supabase app_versions tablosundan okur.
// Koşullu import: web'de dart:io kullanılmaz.

import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

// Koşullu import: native'de dart:io, web'de stub
import 'platform_detector.dart'
    if (dart.library.js_interop) 'platform_stub.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.downloadUrl,
    this.changelog = '',
    this.isForce = false,
  });

  final String version;
  final int buildNumber;
  final String platform;
  final String downloadUrl;
  final String changelog;
  final bool isForce;
}

class UpdateService {
  UpdateService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Aktif platformu tespit et.
  static String get _platform => PlatformDetect.current;

  /// Mevcut uygulama versiyonunu kontrol et.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final platform = _platform;

      if (platform == 'unknown') return null;

      final result = await _db
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .eq('is_active', true)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (result == null) return null;

      final remoteBuild = (result['build_number'] as num?)?.toInt() ?? 0;
      if (remoteBuild <= currentBuild) return null;

      return UpdateInfo(
        version: result['version'] as String? ?? '',
        buildNumber: remoteBuild,
        platform: platform,
        downloadUrl: result['download_url'] as String? ?? '',
        changelog: result['changelog'] as String? ?? '',
        isForce: result['is_force'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
