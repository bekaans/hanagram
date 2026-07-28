// Hanagram — keşfet (TikTok tarzı dikey kaydırma akışı)
//
// Her sayfa tam ekran içerik. Yukarı/aşağı kaydırarak değiştirilir.
// Üstte ince arama çubuğu, altında trending konular.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/utils.dart';
import 'discover_widgets.dart';

// ─── Örnek keşfet verisi ───
final _sampleDiscover = [
  FeedItem(id: 'd1', authorName: 'Merve Demir', authorHandle: 'mervedemir',
    caption: 'Yeni eyeliner trendi: ince kuyruklu grafik liner 🖊️',
    topics: const ['guzellik', 'trend'], likes: 876, commentCount: 54,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
    sponsored: false, why: const {}),
  FeedItem(id: 'd2', authorName: 'FitLife Stüdyo', authorHandle: 'fitlife',
    caption: '30 dakikalık sabah esneme rutini ile enerjik başla 💪',
    topics: const ['spor', 'saglik'], likes: 2341, commentCount: 123,
    createdAt: DateTime.now().subtract(const Duration(hours: 6)).millisecondsSinceEpoch,
    sponsored: false, why: const {}),
  FeedItem(id: 'd3', authorName: 'Chef Özkan', authorHandle: 'chef ozkan',
    caption: 'Protein bombası smoothie tarifi: muz + fıstık ezmesi + yulaf 🥤',
    topics: const ['yemek', 'saglik'], likes: 1567, commentCount: 89,
    createdAt: DateTime.now().subtract(const Duration(hours: 9)).millisecondsSinceEpoch,
    sponsored: false, why: const {'exploration': true}),
  FeedItem(id: 'd4', authorName: 'Moda Haftası', authorHandle: 'modahaftasi',
    caption: '2026 ilkbahar-yaz trendleri: pastel tonlar ve oversized ceketler',
    topics: const ['moda', 'trend'], likes: 4321, commentCount: 234,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)).millisecondsSinceEpoch,
    sponsored: false, why: const {}),
  FeedItem(id: 'd5', authorName: 'TechReview TR', authorHandle: 'techreview',
    caption: 'En iyi 5 profesyonel fotoğraf makinesi karşılaştırması 📷',
    topics: const ['teknoloji', 'fotograf'], likes: 987, commentCount: 67,
    createdAt: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    sponsored: false, why: const {'exploration': true}),
  FeedItem(id: 'd6', authorName: 'Saç Tasarım Akademi', authorHandle: 'sacakademi',
    caption: 'Bob saç kesimi her yüz tipine uyar mı? Uzman görüşü ✂️',
    topics: const ['guzellik', 'saç'], likes: 1234, commentCount: 78,
    createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)).millisecondsSinceEpoch,
    sponsored: false, why: const {}),
];

// ─── Her sayfanın gradient renkleri ───
const _pageColors = [
  [Color(0xFF1A0A2E), Color(0xFF3D1A6E)],  // koyu mor
  [Color(0xFF0A1628), Color(0xFF1A3A5C)],  // koyu lacivert
  [Color(0xFF1A0F0A), Color(0xFF4A2A10)],  // koyu kahve
  [Color(0xFF0A1A14), Color(0xFF1A4A2E)],  // koyu yeşil
  [Color(0xFF1A0A1A), Color(0xFF5A1A3A)],  // koyu pembe
  [Color(0xFF0F0A1A), Color(0xFF2A1A5A)],  // koyu indigo
];

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _pageCtrl = PageController();
  final _searchCtrl = TextEditingController();
  int _currentPage = 0;
  bool _showSearch = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.discover.isNotEmpty ? app.discover : _sampleDiscover;

    // Keşfet ekranı koyu tema ile çalışır (gradient arka plan)
    // Üstteki elementler için beyaz tonları kullanırız.
    const overlayColor = Colors.white;

    return Stack(
      children: [
        // ─── Tam ekran dikey kaydırma akışı ───
        PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (_, i) => FullPageTile(
            item: items[i],
            colors: _pageColors[i % _pageColors.length],
            index: i,
            total: items.length,
          ),
        ),

        // ─── Üstte ince arama + konu filtreleri ───
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _showSearch = !_showSearch),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: _showSearch ? 44 : 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: overlayColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: overlayColor.withValues(alpha: 0.15),
                          width: 0.4,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.search, size: 16,
                              color: overlayColor.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _showSearch
                                ? TextField(
                                    controller: _searchCtrl,
                                    autofocus: true,
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Ara…',
                                      hintStyle: TextStyle(
                                        color: overlayColor.withValues(alpha: 0.4)),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (q) => app.loadDiscover(query: q),
                                  )
                                : Text(
                                    'Keşfet',
                                    style: TextStyle(
                                      color: overlayColor.withValues(alpha: 0.6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                          if (_showSearch)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _showSearch = false);
                              },
                              child: Icon(CupertinoIcons.xmark_circle_fill,
                                  size: 16,
                                  color: overlayColor.withValues(alpha: 0.4)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_showSearch) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        TrendingChip(label: 'Güzellik', icon: CupertinoIcons.sparkles),
                        TrendingChip(label: 'Moda', icon: CupertinoIcons.star),
                        TrendingChip(label: 'Spor', icon: CupertinoIcons.flame),
                        TrendingChip(label: 'Yemek', icon: CupertinoIcons.book),
                        TrendingChip(label: 'Teknoloji', icon: CupertinoIcons.device_laptop),
                        TrendingChip(label: 'Medikal', icon: CupertinoIcons.heart),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ─── Sağ tarafta dikey eylem butonları ───
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              SideAction(
                icon: CupertinoIcons.heart_fill,
                label: fmtCount(items[_currentPage].likes),
                color: Colors.white,
                onTap: () => app.signal(items[_currentPage].id, 'like'),
              ),
              const SizedBox(height: 20),
              SideAction(
                icon: CupertinoIcons.chat_bubble_fill,
                label: '${items[_currentPage].commentCount}',
                color: Colors.white,
                onTap: () => app.signal(items[_currentPage].id, 'comment'),
              ),
              const SizedBox(height: 20),
              SideAction(
                icon: CupertinoIcons.paperplane_fill,
                label: '',
                color: Colors.white,
                onTap: () => app.signal(items[_currentPage].id, 'share'),
              ),
              const SizedBox(height: 20),
              SideAction(
                icon: CupertinoIcons.bookmark,
                label: '',
                color: Colors.white,
                onTap: () => app.signal(items[_currentPage].id, 'save'),
              ),
            ],
          ),
        ),

        // ─── Alt: sayfa göstergesi ───
        Positioned(
          bottom: 76,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length && i < 8; i++)
                Container(
                  width: i == _currentPage ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

}
