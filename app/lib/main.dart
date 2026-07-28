// Hanagram — uygulama girişi
//
// Beş platform tek koddan: iOS, Android, tablet, Windows, macOS (+ web).
// Tüm iş mantığı C++ çekirdektedir; bu katman yalnızca gösterir.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'core/app_state.dart';
import 'core/notification_service.dart';
import 'core/supabase_service.dart';
import 'core/update_service.dart';
import 'package:hanagram_design/design.dart';
import 'features/onboarding/invite_gate.dart';
import 'features/onboarding/update_screen.dart';
import 'features/onboarding/video_splash.dart';
import 'features/onboarding/whats_new_screen.dart';
import 'features/settings/settings_provider.dart';
import 'shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  await NotificationService.init();
  runApp(const HanagramApp());
}

class HanagramApp extends StatefulWidget {
  const HanagramApp({super.key});

  @override
  State<HanagramApp> createState() => _HanagramAppState();
}

class _HanagramAppState extends State<HanagramApp> {
  final _state = AppState();
  final _settings = SettingsProvider();
  bool _videoDone = false;
  UpdateInfo? _pendingUpdate;
  UpdateInfo? _whatsNewInfo;

  @override
  void initState() {
    super.initState();
    _state.boot();
    _checkUpdate();
    _settings.load().then((_) {
      if (mounted) setState(() {});
    });
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _settings.dispose();
    _state.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (mounted && update != null) {
      setState(() => _pendingUpdate = update);
    }
    // Güncelleme sonrası "Yeni Sürüm Özeti" kontrolü
    await _checkWhatsNew();
  }

  /// Mevcut versiyonun changelog'u daha önce gösterildi mi?
  /// Gösterilmediyse WhatsNewScreen'i hazırla.
  Future<void> _checkWhatsNew() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final shouldShow = await WhatsNewScreen.shouldShow(currentVersion);
      if (!shouldShow) return;

      // Supabase'den bu versiyonun changelog'unu çek
      final result = await SupabaseService.client
          .from('app_versions')
          .select('version, changelog')
          .eq('version', 'v$currentVersion')
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      if (result == null) return;
      final changelog = result['changelog'] as String? ?? '';
      if (changelog.isEmpty) return;

      if (mounted) {
        setState(() {
          _whatsNewInfo = UpdateInfo(
            version: currentVersion,
            buildNumber: int.tryParse(info.buildNumber) ?? 0,
            platform: '',
            downloadUrl: '',
            changelog: changelog,
          );
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          // Tema tercihine göre brightness seç: ayarlar ekranındaki seçimi uygula.
          final platformBrightness = MediaQuery.platformBrightnessOf(context);
          final settingsBrightness = _settings.effectiveBrightness;
          final brightness = _settings.themeMode == 'system'
              ? platformBrightness
              : settingsBrightness;
          final colors =
              brightness == Brightness.light ? HgColors.light : HgColors.dark;

          return SettingsScope(
            settings: _settings,
            child: MaterialApp(
              title: 'Hanagram',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(HgColors.light, Brightness.light),
              darkTheme: buildTheme(HgColors.dark, Brightness.dark),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: HgTheme(
                colors: colors,
                child: _root(_state, colors),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _root(AppState state, HgColors c) {
    // Açılışta logo animasyonunu oynat
    if (!_videoDone) {
      return VideoSplash(onDone: () {
        if (mounted) setState(() => _videoDone = true);
      });
    }

    // Zorunlu güncelleme varsa önce onu göster (kapatılamaz)
    if (_pendingUpdate != null && _pendingUpdate!.isForce) {
      return UpdateScreen(
        info: _pendingUpdate!,
        onDismiss: null, // Zorunlu — "Sonra" butonu gizli
      );
    }

    // Güncelleme sonrası "Yeni Sürüm Özeti" ekranı (bir kez gösterilir)
    if (_whatsNewInfo != null) {
      return WhatsNewScreen(
        info: _whatsNewInfo!,
        onDismiss: () {
          if (mounted) setState(() => _whatsNewInfo = null);
        },
      );
    }

    switch (state.status) {
      case CoreStatus.starting:
        return _Splash(colors: c);
      case CoreStatus.failed:
        return _CoreFailure(detail: state.failureDetail ?? '', colors: c);
      case CoreStatus.ready:
        // Opsiyonel güncelleme varsa SnackBar göster
        if (_pendingUpdate != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showUpdateSnack(c);
          });
        }
        return state.session == null ? const InviteGate() : const AppShell();
    }
  }

  void _showUpdateSnack(HgColors c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Hanagram ${_pendingUpdate!.version} mevcut — güncelle',
          style: HgText.body.copyWith(color: c.onBrand),
        ),
        backgroundColor: c.violet,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Güncelle',
          textColor: c.onBrand,
          onPressed: () {
            setState(() {
              final info = _pendingUpdate;
              _pendingUpdate = null;
              if (info != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UpdateScreen(
                      info: info,
                      onDismiss: () {
                        // "Sonra" → uygulamayı kapat
                        SystemNavigator.pop();
                      },
                    ),
                  ),
                );
              }
            });
          },
        ),
      ),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash({required this.colors});
  final HgColors colors;

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late AnimationController _rotCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.colors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _rotCtrl,
              child: const BrandMark(size: 72, animate: true),
            ),
            const SizedBox(height: HgSpace.lg),
            const BrandWordmark(fontSize: 24),
          ],
        ),
      ),
    );
  }
}

/// Çekirdek yüklenemediyse sahte veriye düşülmez — durum açıkça söylenir.
class _CoreFailure extends StatelessWidget {
  const _CoreFailure({required this.detail, required this.colors});
  final String detail;
  final HgColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HgSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.memory_outlined, size: 40, color: c.warning),
                const SizedBox(height: HgSpace.lg),
                Text('Çekirdek yüklenemedi',
                    style: HgText.title.copyWith(color: c.text)),
                const SizedBox(height: HgSpace.sm),
                Text(
                  'Uygulama C++ çekirdeğine bağlanamadı. Uydurma içerik göstermek '
                  'yerine durumu bildiriyoruz.',
                  style: HgText.body.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: HgSpace.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(HgSpace.md),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(detail,
                      style: HgText.caption.copyWith(
                          color: c.textMuted, fontFamily: 'monospace')),
                ),
                const SizedBox(height: HgSpace.lg),
                Text('Çözüm', style: HgText.heading.copyWith(color: c.text)),
                const SizedBox(height: HgSpace.sm),
                Text(
                  'core/ dizininde çekirdeği derle:\n'
                  '  cmake -S . -B build -G Ninja\n'
                  '  cmake --build build\n\n'
                  'Ardından uygulamayı yeniden başlat.',
                  style: HgText.small
                      .copyWith(color: c.textMuted, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
