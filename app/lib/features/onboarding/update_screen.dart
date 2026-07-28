// Hanagram — güncelleme ekranı (5 platform)
//
// Tek sorumluluk: yeni versiyon bilgisi göstermek + indirme bağlantısı.
// "Sonra" → uygulamayı kapatır.
// "Güncelle" → platforma göre indirme/mag linki açar.
// isForce ise "Sonra" butonu gösterilmez.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/update_service.dart';
import 'package:hanagram_design/design.dart';

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({
    super.key,
    required this.info,
    this.onDismiss,
  });

  final UpdateInfo info;
  final VoidCallback? onDismiss;

  /// Platforma göre doğru indirmeURL'ini döndür.
  String get _effectiveUrl {
    final platform = info.platform;
    final url = info.downloadUrl;

    // Web ise sayfayı yenile
    if (platform == 'web') return '';

    // iOS/macOS ise App Store/TestFlight linki olmalı (sunucudan gelir)
    // Android ise APK linki olmalı
    // Windows ise .exe linki olmalı
    return url;
  }

  Future<void> _download(BuildContext context) async {
    final url = _effectiveUrl;

    // Web platformunda sayfayı yenile
    if (url.isEmpty && info.platform == 'web') {
      // Web'de refresh
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sayfa yenileniyor...')),
        );
      }
      return;
    }

    if (url.isEmpty) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _dismiss() {
    // "Sonra" → uygulamayı kapat
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return PopScope(
      canPop: false, // Geri tuşu çalışmaz (zorunlu güncelleme)
      child: Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            // Arka plan ışık lekeleri
            Positioned(
              top: -140,
              left: -90,
              child: _Glow(color: c.violet, size: 340),
            ),
            Positioned(
              bottom: -160,
              right: -110,
              child: _Glow(color: c.blue, size: 400),
            ),

            // Geri butonu (sadece zorunlu güncelleme değilse)
            if (onDismiss != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface.withValues(alpha: 0.8),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 18, color: c.text),
                  ),
                ),
              ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(HgSpace.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Güncelleme ikonu
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  c.success.withValues(alpha: 0.2),
                                  c.blue.withValues(alpha: 0.2),
                                ],
                              ),
                              border: Border.all(
                                color: c.success.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              Icons.system_update,
                              size: 36,
                              color: c.success,
                            ),
                          ),
                        ),
                        const SizedBox(height: HgSpace.xl),

                        // Başlık
                        Text(
                          'Yeni Güncelleme',
                          style: HgText.title.copyWith(color: c.text),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: HgSpace.sm),

                        // Versiyon + platform
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HgChip(
                                label: 'v${info.version}',
                                color: c.success,
                              ),
                              const SizedBox(width: HgSpace.sm),
                              HgChip(
                                label: info.platform.toUpperCase(),
                                color: c.blue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: HgSpace.xl),

                        // Changelog
                        if (info.changelog.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(HgSpace.lg),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius:
                                  BorderRadius.circular(HgRadius.md),
                              border: Border.all(color: c.border),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Değişiklikler',
                                  style: HgText.bodyStrong
                                      .copyWith(color: c.text),
                                ),
                                const SizedBox(height: HgSpace.sm),
                                Text(
                                  info.changelog,
                                  style: HgText.body
                                      .copyWith(color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: HgSpace.xl),
                        ],

                        // Platform bilgi notu
                        Container(
                          padding: const EdgeInsets.all(HgSpace.md),
                          decoration: BoxDecoration(
                            color: c.violet.withValues(alpha: 0.06),
                            borderRadius:
                                BorderRadius.circular(HgRadius.sm),
                            border: Border.all(
                              color: c.violet.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: c.violet),
                              const SizedBox(width: HgSpace.sm),
                              Expanded(
                                child: Text(
                                  _platformNote,
                                  style: HgText.caption
                                      .copyWith(color: c.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: HgSpace.xl),

                        // Güncelle butonu
                        _UpdateButton(
                          label: 'Şimdi Güncelle',
                          icon: Icons.download,
                          color: c.success,
                          onPressed: () => _download(context),
                        ),

                        // Sonra butonu (sadece zorunlu değilse)
                        if (onDismiss != null) ...[
                          const SizedBox(height: HgSpace.md),
                          Center(
                            child: TextButton(
                              onPressed: _dismiss,
                              child: Text(
                                'Sonra',
                                style: HgText.body
                                    .copyWith(color: c.textMuted),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: HgSpace.sm),

                        // Zorunlu güncelleme notu
                        if (info.isForce)
                          Text(
                            'Bu güncelleme zorunludur. Güncellemeden devam edemezsiniz.',
                            textAlign: TextAlign.center,
                            style: HgText.caption
                                .copyWith(color: c.warning),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _platformNote {
    switch (info.platform) {
      case 'android':
        return 'APK dosyası indirilecek. Kurulum için bilinmeyen kaynaklara izin vermeniz gerekebilir.';
      case 'ios':
        return 'App Store açılacak. Güncellemeyi App Store\'dan yükleyebilirsiniz.';
      case 'macos':
        return 'App Store açılacak. Güncellemeyi App Store\'dan yükleyebilirsiniz.';
      case 'windows':
        return 'Güncelleme dosyası indirilecek. Kurulum sihirbazı başlayacaktır.';
      case 'web':
        return 'Sayfa yenilenecek ve en güncel sürüme geçilecek.';
      default:
        return 'Güncelleme bağlantısı açılacak.';
    }
  }
}

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HgRadius.md),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: HgSpace.sm),
            Text(
              label,
              style: HgText.bodyStrong.copyWith(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
