// Hanagram — açılış splash ekranı
//
// MP4 logo animasyonu 1.5x hızında oynatılır.
// 2 sn sonra dokunulursa otomatik geçilir.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:hanagram_design/design.dart';

/// Web'de bu dosya GitHub Pages üzerinden güvenilir şekilde stream edilemiyor
/// (ara sıra 503 dönüyor) — Cloudflare R2'de (ücretsiz, sınırsız egress)
/// barındırılıyor. Yerel platformlarda (iOS/Android/macOS/Windows) dosya
/// uygulamayla birlikte paketlendiği için bu sorun hiç yaşanmıyor, oradan
/// okunmaya devam ediliyor.
const String _webIntroVideoUrl =
    'https://pub-11522199468a4dfc982cc7a2eb02c4c7.r2.dev/hanagram%20logo%20animasyon.mp4';

class VideoSplash extends StatefulWidget {
  const VideoSplash({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<VideoSplash> createState() => _VideoSplashState();
}

class _VideoSplashState extends State<VideoSplash> {
  late VideoPlayerController _ctrl;
  bool _done = false;
  bool _ready = false;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = (kIsWeb
      ? VideoPlayerController.networkUrl(Uri.parse(_webIntroVideoUrl))
      : VideoPlayerController.asset('assets/images/intro.mp4'))
      ..setVolume(0)
      ..setPlaybackSpeed(1.5) // 1.5x hız
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _ctrl.play();
      }).catchError((_) {
        // Video yüklenemezse (web vb.) direkt geç
        _finish();
      });

    _ctrl.addListener(_onVideoProgress);

    // 2 saniye sonra dokunma izni ver
    _tapTimer = Timer(const Duration(seconds: 2), () {});

    // 5 saniye sonra video hâlâ yüklenmediyse otomatik geç
    Timer(const Duration(seconds: 5), () {
      if (!_done && mounted) _finish();
    });
  }

  void _onVideoProgress() {
    if (_done) return;
    final pos = _ctrl.value.position;
    final dur = _ctrl.value.duration;
    // Son 200ms'de veya bittiyken geç
    if (dur.inMilliseconds > 0 && pos.inMilliseconds >= dur.inMilliseconds - 200) {
      _finish();
    }
  }

  void _onTap() {
    // 2 saniye geçtikten sonra dokunma çalışır
    if (_tapTimer != null && _tapTimer!.isActive) return;
    _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _ctrl.removeListener(_onVideoProgress);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HgColors.dark.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video — tam ekran
            if (_ready)
              Center(
                child: AspectRatio(
                  aspectRatio: _ctrl.value.aspectRatio,
                  child: VideoPlayer(_ctrl),
                ),
              )
            else
              // Yüklenirken PNG fallback
              Center(
                child: Image.asset(
                  'assets/images/intro.png',
                  width: 440,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
