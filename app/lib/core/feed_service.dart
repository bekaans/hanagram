// Hanagram — akış ve keşfet servisi
//
// Tek sorumluluk: akış yükleme, keşfet, sinyal kaydetme, gönderi oluşturma.
import 'package:flutter/foundation.dart' show VoidCallback;

import 'package:hanagram_design/design.dart';
import 'app_state.dart';

class FeedService {
  FeedService(this._core, this._onUpdate);

  final HanagramCore _core;
  final VoidCallback _onUpdate;

  List<FeedItem> feed = const [];
  List<FeedItem> discover = const [];
  double profileConfidence = 0;

  void loadFeed(String userId, {String mode = 'foryou'}) {
    try {
      final d = _core.call('feed.get', {
        'userId': userId,
        'mode': mode,
        'limit': 25,
      });
      feed = ((d['items'] as List?) ?? const [])
          .map((e) => FeedItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      profileConfidence = (d['profileConfidence'] as num?)?.toDouble() ?? 0;
    } on Exception catch (_) {
      feed = const [];
    }
    _onUpdate();
  }

  void loadDiscover(String userId, {String query = ''}) {
    try {
      final d = _core.call('discover.get', {
        'userId': userId,
        'query': query,
        'limit': 30,
      });
      discover = ((d['items'] as List?) ?? const [])
          .map((e) => FeedItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on Exception catch (_) {
      discover = const [];
    }
    _onUpdate();
  }

  void signal(String userId, String itemId, String kind, {int dwellMs = 0}) {
    try {
      _core.callRaw('signal.record', {
        'userId': userId,
        'itemId': itemId,
        'kind': kind,
        'dwellMs': dwellMs,
      });
    } on Exception catch (_) {}
  }

  void createPost(String authorId, String caption, List<String> topics) {
    try {
      _core.callRaw('post.create', {
        'authorId': authorId,
        'caption': caption,
        'topics': topics,
        'kind': 'image',
      });
      loadFeed(authorId);
    } on Exception catch (_) {}
  }
}
