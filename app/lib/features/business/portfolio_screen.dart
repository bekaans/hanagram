// Hanagram — Portfolyo ekranı
//
// İşletmenin fotoğraf/video portföyünü ızgara biçiminde gösterir.
// Veri Supabase posts tablosundan (is_portfolio=true) gelir.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/post_service.dart';

/// Portföy medya kalemi.
class _PortfolioItem {
  const _PortfolioItem({
    required this.id,
    required this.title,
    required this.type,
    this.mediaUrl = '',
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.likedByMe = false,
  });

  final String id;
  final String title;
  final String type; // 'photo' veya 'video'
  final String mediaUrl;
  final int likes;
  final int comments;
  final int shares;
  final bool likedByMe;

  bool get isVideo => type == 'video';

  factory _PortfolioItem.fromJson(Map<String, dynamic> j) => _PortfolioItem(
        id: j['id'] as String? ?? '',
        title: j['caption'] as String? ?? '',
        type: j['mediaType'] as String? ?? 'photo',
        mediaUrl: j['mediaUrl'] as String? ?? '',
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        likedByMe: j['likedByMe'] as bool? ?? false,
      );

  _PortfolioItem copyWith({int? likes, bool? likedByMe}) => _PortfolioItem(
        id: id,
        title: title,
        type: type,
        mediaUrl: mediaUrl,
        likes: likes ?? this.likes,
        comments: comments,
        shares: shares,
        likedByMe: likedByMe ?? this.likedByMe,
      );
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<_PortfolioItem> _items = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    final result = await PostService.getPortfolio();
    _items = result.map((e) => _PortfolioItem.fromJson(e)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleLike(int index) async {
    final item = _items[index];
    final wasLiked = item.likedByMe;
    setState(() {
      _items[index] = item.copyWith(
        likes: wasLiked ? item.likes - 1 : item.likes + 1,
        likedByMe: !wasLiked,
      );
    });
    final ok = await PostService.toggleLike(item.id);
    if (ok == null && mounted) {
      setState(() => _items[index] = item);
    }
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
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
          // Medya (gerçek görsel varsa göster, yoksa gradient placeholder)
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
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
                fit: StackFit.expand,
                children: [
                  if (item.mediaUrl.isNotEmpty && !item.isVideo)
                    Image.network(
                      item.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(Icons.image_outlined,
                            size: 40, color: c.textMuted),
                      ),
                    )
                  else
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
