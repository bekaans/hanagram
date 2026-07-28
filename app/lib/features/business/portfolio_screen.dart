// Hanagram — Portfolyo ekranı (bağımsız, Supabase bağımlılığı yok)
//
// İşletmenin fotoğraf/video portföyünü ızgara biçiminde gösterir.
// Arkadram'ın portfoy.tsx ekranının Flutter karşılığı.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';

/// Portföy medya kalemi.
class _PortfolioItem {
  const _PortfolioItem({
    required this.id,
    required this.title,
    required this.type,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
  });

  final String id;
  final String title;
  final String type; // 'photo' veya 'video'
  final int likes;
  final int comments;
  final int shares;

  bool get isVideo => type == 'video';
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late List<_PortfolioItem> _items;

  @override
  void initState() {
    super.initState();
    _items = _samplePortfolio();
  }

  void _toggleLike(int index) {
    final item = _items[index];
    setState(() {
      _items[index] = _PortfolioItem(
        id: item.id, title: item.title, type: item.type,
        likes: item.likes + 1, comments: item.comments, shares: item.shares,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Portfolyo', style: HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      body: SafeArea(
        bottom: false,
        child: _items.isEmpty
            ? EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'Portfolyo boş',
                message: 'Medya galerisinden içerik ekleyin.',
              )
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.lg, HgSpace.lg, 96),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: HgSpace.sm,
                  crossAxisSpacing: HgSpace.sm,
                  childAspectRatio: 0.75,
                ),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _PortfolioCard(
                    item: item,
                    onLike: () => _toggleLike(index),
                  );
                },
              ),
      ),
    );
  }
}

// ─── Portföy kartı ───

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.item, required this.onLike});
  final _PortfolioItem item;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    // Gerçek uygulamada burada image/video gösterilir.
    // Şimdilik gradient placeholder kullanıyoruz.
    return HgCard(
      padding: EdgeInsets.zero,
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medya placeholder
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c.violet.withValues(alpha: 0.3),
                    c.blue.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(HgRadius.md)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      item.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                      size: 40,
                      color: c.textMuted,
                    ),
                  ),
                  if (item.isVideo)
                    Positioned(
                      top: HgSpace.sm,
                      right: HgSpace.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(HgRadius.sm),
                        ),
                        child: Text('Video', style: HgText.caption.copyWith(color: Colors.white, shadows: null)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Bilgi satırı
          Padding(
            padding: const EdgeInsets.all(HgSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: HgText.caption.copyWith(color: c.text, shadows: null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: HgSpace.xs),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border, size: 14, color: c.coral),
                          const SizedBox(width: 2),
                          Text('${item.likes}', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                        ],
                      ),
                    ),
                    const SizedBox(width: HgSpace.md),
                    Icon(Icons.chat_bubble_outline, size: 14, color: c.textMuted),
                    const SizedBox(width: 2),
                    Text('${item.comments}', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                    const Spacer(),
                    Icon(Icons.share_outlined, size: 14, color: c.textMuted),
                    const SizedBox(width: 2),
                    Text('${item.shares}', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Örnek portföy verisi ───

List<_PortfolioItem> _samplePortfolio() {
  return [
    const _PortfolioItem(id: 'pf1', title: 'Stüdyo çekimi — Elif', type: 'photo', likes: 45, comments: 8, shares: 3),
    const _PortfolioItem(id: 'pf2', title: 'Reels kurgu — makyaj', type: 'video', likes: 128, comments: 22, shares: 15),
    const _PortfolioItem(id: 'pf3', title: 'Dr. Ahmet Kaya reklam', type: 'photo', likes: 67, comments: 5, shares: 2),
    const _PortfolioItem(id: 'pf4', title: 'Saç bakım önce-sonra', type: 'photo', likes: 89, comments: 12, shares: 7),
    const _PortfolioItem(id: 'pf5', title: 'Tanıtım videosu — Nova', type: 'video', likes: 203, comments: 34, shares: 28),
    const _PortfolioItem(id: 'pf6', title: 'Kampanya afişi — yaz', type: 'photo', likes: 56, comments: 3, shares: 1),
    const _PortfolioItem(id: 'pf7', title: 'Kaş laminasyonu süreci', type: 'video', likes: 94, comments: 11, shares: 6),
    const _PortfolioItem(id: 'pf8', title: 'Mekan tanıtımı', type: 'photo', likes: 112, comments: 15, shares: 9),
  ];
}
