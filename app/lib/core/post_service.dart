// Hanagram — gönderi servisi (feed + portfolyo)
//
// posts/post_likes/post_comments tablolarıyla çalışır. Beğeni/yorum sayıları
// PostgREST aggregate embed yerine iki ayrı sorguyla istemci tarafında sayılır
// (sürüm bağımsız, daha güvenilir).
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class PostService {
  PostService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Bir kullanıcının portfolyo gönderilerini getir (varsayılan: kendi işletmen).
  static Future<List<Map<String, dynamic>>> getPortfolio({
    String? authorId,
  }) async {
    try {
      final targetId = authorId ?? await SupabaseService.myDbId();
      if (targetId == null) return [];

      final posts = await _db
          .from('posts')
          .select('*, media(file_path, type)')
          .eq('author_id', targetId)
          .eq('is_portfolio', true)
          .order('created_at', ascending: false);

      return _attachCounts((posts as List).cast<Map<String, dynamic>>());
    } catch (_) {
      return [];
    }
  }

  /// Genel akış — herkesin gönderileri (feed/keşfet ekranı).
  /// [followingOnly] true ise sadece takip edilen kullanıcıların gönderileri.
  static Future<List<Map<String, dynamic>>> getFeed({
    int limit = 50,
    bool followingOnly = false,
    String query = '',
  }) async {
    try {
      var q = _db.from('posts').select(
          '*, media(file_path, type), author:users!posts_author_id_fkey(full_name, username, avatar_url)');

      if (followingOnly) {
        final myId = await SupabaseService.myDbId();
        if (myId == null) return [];
        final follows = await _db
            .from('followers')
            .select('following_id')
            .eq('follower_id', myId);
        final followingIds = (follows as List)
            .map((r) => (r as Map)['following_id'] as String)
            .toList();
        if (followingIds.isEmpty) return [];
        q = q.inFilter('author_id', followingIds);
      }
      if (query.isNotEmpty) {
        q = q.or('caption.ilike.%$query%,topic.ilike.%$query%');
      }

      final posts = await q.order('created_at', ascending: false).limit(limit);

      return _attachCounts((posts as List).cast<Map<String, dynamic>>());
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _attachCounts(
    List<Map<String, dynamic>> posts,
  ) async {
    if (posts.isEmpty) return [];
    final ids = posts.map((p) => p['id'] as String).toList();
    final myId = await SupabaseService.myDbId();

    final likes =
        await _db.from('post_likes').select('post_id, user_id').inFilter('post_id', ids);
    final comments =
        await _db.from('post_comments').select('post_id').inFilter('post_id', ids);

    final likeCounts = <String, int>{};
    final likedByMe = <String>{};
    for (final row in (likes as List)) {
      final m = row as Map<String, dynamic>;
      final pid = m['post_id'] as String;
      likeCounts[pid] = (likeCounts[pid] ?? 0) + 1;
      if (myId != null && m['user_id'] == myId) likedByMe.add(pid);
    }
    final commentCounts = <String, int>{};
    for (final row in (comments as List)) {
      final pid = (row as Map)['post_id'] as String;
      commentCounts[pid] = (commentCounts[pid] ?? 0) + 1;
    }

    return posts.map((p) {
      final media = p['media'] as Map<String, dynamic>?;
      final author = p['author'] as Map<String, dynamic>?;
      final id = p['id'] as String;
      return {
        'id': id,
        'authorId': p['author_id'],
        'authorName': author?['full_name'] ?? '',
        'authorHandle': author?['username'] ?? '',
        'mediaUrl': media?['file_path'] ?? '',
        'mediaType': media?['type'] ?? 'photo',
        'caption': p['caption'] ?? '',
        'topic': p['topic'] ?? '',
        'likes': likeCounts[id] ?? 0,
        'comments': commentCounts[id] ?? 0,
        'likedByMe': likedByMe.contains(id),
        'createdAt': DateTime.tryParse(p['created_at'] as String? ?? ''),
      };
    }).toList();
  }

  /// Yeni gönderi oluştur (portfolyo veya feed).
  static Future<String?> createPost({
    String? mediaId,
    String caption = '',
    String topic = '',
    bool isPortfolio = false,
  }) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return null;

      final result = await _db.from('posts').insert({
        'author_id': myId,
        'media_id': mediaId,
        'caption': caption,
        'topic': topic,
        'is_portfolio': isPortfolio,
      }).select('id').maybeSingle();

      return result?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deletePost(String postId) async {
    try {
      await _db.from('posts').delete().eq('id', postId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Beğeniyi aç/kapat. Yeni beğeni durumunu döner (başarısızsa null).
  static Future<bool?> toggleLike(String postId) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return null;

      final existing = await _db
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', myId)
          .maybeSingle();

      if (existing != null) {
        await _db
            .from('post_likes')
            .delete()
            .match({'post_id': postId, 'user_id': myId});
        return false;
      } else {
        await _db.from('post_likes').insert({
          'post_id': postId,
          'user_id': myId,
        });
        return true;
      }
    } catch (_) {
      return null;
    }
  }

  /// Bir gönderinin yorumlarını getir.
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    try {
      final result = await _db
          .from('post_comments')
          .select('*, author:users!post_comments_author_id_fkey(full_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (result as List).cast<Map<String, dynamic>>().map((c) {
        final author = c['author'] as Map<String, dynamic>?;
        return {
          'id': c['id'],
          'authorName': author?['full_name'] ?? '',
          'content': c['content'],
          'createdAt': DateTime.tryParse(c['created_at'] as String? ?? ''),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Kendi gönderilerimin toplam beğeni+yorum sayısı (işletme paneli özeti için).
  static Future<int> getMyEngagementTotal() async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return 0;

      final posts =
          await _db.from('posts').select('id').eq('author_id', myId);
      final postIds =
          (posts as List).map((p) => (p as Map)['id'] as String).toList();
      if (postIds.isEmpty) return 0;

      final results = await Future.wait([
        _db.from('post_likes').select('post_id').inFilter('post_id', postIds),
        _db
            .from('post_comments')
            .select('id')
            .inFilter('post_id', postIds),
      ]);

      return (results[0] as List).length + (results[1] as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> addComment(String postId, String content) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return false;

      await _db.from('post_comments').insert({
        'post_id': postId,
        'author_id': myId,
        'content': content,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
