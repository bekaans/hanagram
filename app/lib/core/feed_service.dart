// Hanagram — akış ve keşfet servisi
//
// Tek sorumluluk: akış yükleme, keşfet, sinyal kaydetme, gönderi oluşturma.
// Supabase posts/post_likes tablolarını kullanır (eski yerel C++ öneri motoru
// artık veri kaynağı değil — bkz. DURUM.md "Backend entegrasyon durumu").
import 'package:flutter/foundation.dart' show VoidCallback;

import 'app_state.dart';
import 'post_service.dart';

class FeedService {
  FeedService(this._onUpdate);

  final VoidCallback _onUpdate;

  List<FeedItem> feed = const [];
  List<FeedItem> discover = const [];
  double profileConfidence = 0;

  Future<void> loadFeed({String mode = 'foryou'}) async {
    final result = await PostService.getFeed(followingOnly: mode == 'following');
    feed = result.map(_toFeedItem).toList();
    _onUpdate();
  }

  Future<void> loadDiscover({String query = ''}) async {
    final result = await PostService.getFeed(query: query);
    discover = result.map(_toFeedItem).toList();
    _onUpdate();
  }

  Future<void> signal(String itemId, String kind, {int dwellMs = 0}) async {
    // Beğeni gerçek kalıcı bir eylem — geri kalan sinyaller (view/dwell/hide)
    // öneri motoru olmadan anlamsız, sessizce yok sayılır.
    if (kind == 'like') {
      await PostService.toggleLike(itemId);
    }
  }

  Future<void> createPost(String caption, List<String> topics) async {
    await PostService.createPost(
      caption: caption,
      topic: topics.isNotEmpty ? topics.first : '',
    );
  }

  FeedItem _toFeedItem(Map<String, dynamic> p) {
    final topic = p['topic'] as String? ?? '';
    return FeedItem(
      id: p['id'] as String,
      authorName: p['authorName'] as String? ?? '',
      authorHandle: p['authorHandle'] as String? ?? '',
      caption: p['caption'] as String? ?? '',
      topics: topic.isNotEmpty ? [topic] : const [],
      likes: (p['likes'] as num?)?.toInt() ?? 0,
      commentCount: (p['comments'] as num?)?.toInt() ?? 0,
      createdAt: (p['createdAt'] as DateTime?)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      sponsored: false,
      why: const {},
      likedByMe: p['likedByMe'] as bool? ?? false,
    );
  }
}
