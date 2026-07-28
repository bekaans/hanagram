// Hanagram — akış
//
// Sıralamayı bu ekran YAPMAZ. Liste C++ çekirdeğinden sıralı gelir; ekranın işi
// göstermek ve kullanıcı davranışını sinyal olarak geri bildirmektir.
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import '../../shell/compose_sheet.dart';
import 'feed_widgets.dart';

// ─── Örnek gönderi verisi ───
final _sampleFeed = [
  FeedItem(
    id: 's1', authorName: 'Elif Yılmaz', authorHandle: 'elifyilmaz',
    caption: 'Bugünkü makyaj çalışmam 💄 Doğal tonlar her zaman kazanır!',
    topics: const ['guzellik', 'makyaj'], likes: 342, commentCount: 28,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
    sponsored: false, why: const {},
  ),
  FeedItem(
    id: 's2', authorName: 'Dr. Ahmet Kaya', authorHandle: 'dr.ahmetkaya',
    caption: 'Cilt bakımı rutininizde mutlaka bulunması gereken 3 ürün: SPF, retinol ve hyaluronik asit.',
    topics: const ['medikal', 'cilt'], likes: 891, commentCount: 67,
    createdAt: DateTime.now().subtract(const Duration(hours: 5)).millisecondsSinceEpoch,
    sponsored: false, why: const {},
  ),
  FeedItem(
    id: 's3', authorName: 'Studio Nova', authorHandle: 'studionova',
    caption: 'Yeni çekim için mekan arıyoruz 📸 İstanbul Anadolu Yakası önerilerinizi bekliyoruz.',
    topics: const ['icerik', 'fotograf'], likes: 156, commentCount: 43,
    createdAt: DateTime.now().subtract(const Duration(hours: 8)).millisecondsSinceEpoch,
    sponsored: false, why: const {'exploration': true},
  ),
  FeedItem(
    id: 's4', authorName: 'Hanagram', authorHandle: 'hanagram',
    caption: '🎯 Hanagram\'a hoş geldin! İlk haftanda sana özel içerikler hazırlanıyor.',
    topics: const ['hanagram'], likes: 2048, commentCount: 12,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
    sponsored: true, why: const {},
  ),
  FeedItem(
    id: 's5', authorName: 'Zeynep Arslan', authorHandle: 'zeyneparslan',
    caption: 'Bugün çok güzel bir kaş laminasyonu yaptım! Detaylı video çok yakında 🎬',
    topics: const ['guzellik', 'icerik'], likes: 527, commentCount: 34,
    createdAt: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    sponsored: false, why: const {},
  ),
  FeedItem(
    id: 's6', authorName: 'Cenk Demir', authorHandle: 'cenkdemir',
    caption: 'Fitness antrenman programı paylaşımı: 12 haftalık kickboks planı 🥊',
    topics: const ['spor', 'egitim'], likes: 1243, commentCount: 89,
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)).millisecondsSinceEpoch,
    sponsored: false, why: const {'exploration': true},
  ),
];

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _mode = 'foryou';

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final app = AppScope.of(context);
    final items = app.feed.isNotEmpty ? app.feed : _sampleFeed;

    return Column(
      children: [
        _GlassTopBar(
          mode: _mode,
          onMode: (m) {
            setState(() => _mode = m);
            app.loadFeed(mode: m);
          },
        ),
        Expanded(
          child: app.busy && app.feed.isEmpty && _mode == 'foryou'
              ? Center(child: CupertinoActivityIndicator(color: c.violet))
              : RefreshIndicator(
                  color: c.violet,
                  onRefresh: () => app.loadFeed(mode: _mode),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        HgSpace.lg, HgSpace.sm, HgSpace.lg, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: HgSpace.lg),
                    itemBuilder: (_, i) => PostCard(item: items[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Glass üst bar ───

class _GlassTopBar extends StatelessWidget {
  const _GlassTopBar({
    required this.mode,
    required this.onMode,
  });

  final String mode;
  final ValueChanged<String> onMode;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.md, HgSpace.lg, HgSpace.md),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : c.surface.withValues(alpha: 0.90),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : c.border.withValues(alpha: 0.3),
                width: 0.3,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ComposeSheet(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: c.violet.withValues(alpha: 0.20),
                        width: 0.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.plus, size: 13, color: c.violet),
                        const SizedBox(width: 4),
                        Text('Oluştur',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.violet,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: HgSpace.lg),
                GestureDetector(
                  onTap: () => onMode('foryou'),
                  child: Text(
                    'Senin için',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: mode == 'foryou' ? FontWeight.w900 : FontWeight.w500,
                      color: mode == 'foryou' ? c.text : c.textFaint,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('|',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        color: c.textFaint,
                      )),
                ),
                GestureDetector(
                  onTap: () => onMode('following'),
                  child: Text(
                    'Takip',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: mode == 'following' ? FontWeight.w900 : FontWeight.w500,
                      color: mode == 'following' ? c.text : c.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
