// Hanagram — uygulama durumu
//
// Yalnızca SUNUM durumu tutar (hangi sekme açık, yükleniyor mu, elde hangi liste var).
// İş kuralı servislerde: FeedService, ProfileService.
import 'web_compat.dart';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hanagram_design/design.dart';
import 'feed_service.dart';
import 'notification_service.dart';
import 'referral_service.dart';
import 'supabase_service.dart';

class Session {
  const Session({
    required this.userId,
    required this.name,
    required this.handle,
    required this.accountType,
    required this.memberNumber,
    this.bio = '',
    this.sector = '',
  });

  final String userId;
  final String name;
  final String handle;
  final String accountType;
  final int memberNumber;
  final String bio;
  final String sector;

  bool get isBusiness => accountType == 'business';
  bool get isCreator => accountType == 'creator';

  static Session fromJson(Map<String, dynamic> j) => Session(
        userId: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        accountType: j['accountType'] as String? ?? 'personal',
        memberNumber: (j['memberNumber'] as num?)?.toInt() ?? 0,
        bio: j['bio'] as String? ?? '',
        sector: j['sector'] as String? ?? '',
      );
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.authorName,
    required this.authorHandle,
    required this.caption,
    required this.topics,
    required this.likes,
    required this.commentCount,
    required this.createdAt,
    required this.sponsored,
    required this.why,
    this.likedByMe = false,
  });

  final String id;
  final String authorName;
  final String authorHandle;
  final String caption;
  final List<String> topics;
  final int likes;
  final int commentCount;
  final int createdAt;
  final bool sponsored;
  final Map<String, dynamic> why;
  final bool likedByMe;

  bool get isExploration => why['exploration'] == true;

  static FeedItem fromJson(Map<String, dynamic> j) => FeedItem(
        id: j['id'] as String? ?? '',
        authorName: j['authorName'] as String? ?? '',
        authorHandle: j['authorHandle'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        topics: ((j['topics'] as List?) ?? const []).map((e) => '$e').toList(),
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        commentCount: (j['commentCount'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        sponsored: j['sponsored'] == true,
        why: ((j['_why'] as Map?) ?? const {}).cast<String, dynamic>(),
      );
}

enum CoreStatus { starting, ready }

class AppState extends ChangeNotifier {
  HanagramCore? _core;
  CoreStatus status = CoreStatus.starting;

  Session? session;
  bool busy = false;

  /// Alt bar sekmeleri arası geçiş için kontrolcü.
  /// Profil → Mesajlar gibi ekranlar arası geçişlerde kullanılır.
  final ValueNotifier<int> tabController = ValueNotifier(0);

  // Servisler — boot() sonrasında geçerli.
  // feedService Supabase tabanlı, çekirdeksiz de çalışır.
  late final FeedService feedService;

  // Geriye uyumluluk: doğrudan erişim (ekranlar değiştirmeden çalışmaya devam eder).
  List<FeedItem> get feed => feedService.feed;
  set feed(List<FeedItem> v) => feedService.feed = v;
  List<FeedItem> get discover => feedService.discover;
  set discover(List<FeedItem> v) => feedService.discover = v;
  double get profileConfidence => feedService.profileConfidence;

  HanagramCore get core {
    final c = _core;
    if (c == null) throw CoreUnavailable('başlatılmadı');
    return c;
  }

  String get coreVersion => _core?.version ?? '—';

  Future<void> boot() async {
    // feedService artık Supabase üzerinden çalışır — çekirdek şart değil.
    feedService = FeedService(() => notifyListeners());

    try {
      String dir = '';
      try {
        final d = await getApplicationSupportDirectory();
        dir = '${d.path}${pathSeparator}hanagram';
      } catch (_) {
        dir = '';
      }
      _core = HanagramCore.start(dir);
    } catch (_) {
      // Çekirdek yüklenemedi (ör. Android/iOS/Windows'ta henüz derlenmedi).
      // Auth/mesaj/randevu/CRM/görev/ekip/akış Supabase üzerinden çalıştığı
      // için bu artık uygulamayı BLOKLAMAZ.
      _core = null;
    }

    // Supabase oturumunu geri yükle (çekirdek durumundan bağımsız).
    await _restoreSession();

    status = CoreStatus.ready;
    notifyListeners();
  }

  /// Supabase'de mevcut oturum varsa profil bilgisini çek → session'ı doldur.
  Future<void> _restoreSession() async {
    try {
      final authUser = SupabaseService.user;
      if (authUser == null) return;

      final profile = await ReferralService.getProfile(authUser.id);
      if (profile == null) return;

      session = Session(
        userId: profile['id'] as String? ?? '',
        name: profile['full_name'] as String? ?? '',
        handle: profile['username'] as String? ?? '',
        accountType: profile['account_type'] as String? ?? 'personal',
        memberNumber: 0,
        bio: profile['bio'] as String? ?? '',
        sector: profile['sector'] as String? ?? '',
      );

      // OneSignal user ID'yi eşle (bildirimler için)
      await NotificationService.linkUser(profile['id'] as String? ?? '');
    } catch (_) {
      // Oturum geri yüklenemedi — InviteGate'e düşecek
    }
  }

  /// Dışarıdan durum değişikliği bildir (ör: kayıt sonrası session güncelleme).
  void updateSession(Session s) {
    session = s;
    notifyListeners();
  }

  Future<void> loadFeed({String mode = 'foryou'}) async {
    if (session == null) return;
    busy = true;
    notifyListeners();
    await feedService.loadFeed(mode: mode);
    busy = false;
    notifyListeners();
  }

  Future<void> loadDiscover({String query = ''}) async {
    if (session == null) return;
    await feedService.loadDiscover(query: query);
    notifyListeners();
  }

  void signal(String itemId, String kind, {int dwellMs = 0}) {
    if (session == null) return;
    feedService.signal(itemId, kind, dwellMs: dwellMs);
  }

  Future<void> createPost(String caption, List<String> topics) async {
    if (session == null) return;
    await feedService.createPost(caption, topics);
    await loadFeed();
  }

  void updateProfile({String? name, String? bio, String? sector, String? accountType}) {
    final s = session;
    if (s == null) return;
    final data = <String, dynamic>{};
    if (name != null) data['full_name'] = name;
    if (bio != null) data['bio'] = bio;
    if (sector != null) data['sector'] = sector;
    if (accountType != null) data['account_type'] = accountType;
    if (data.isEmpty) return;

    // Supabase'e yaz + local session'ı güncelle
    SupabaseService.client
        .from('users')
        .update(data)
        .eq('auth_id', s.userId)
        .then((_) {
      session = Session(
        userId: s.userId,
        name: name ?? s.name,
        handle: s.handle,
        accountType: accountType ?? s.accountType,
        memberNumber: s.memberNumber,
        bio: bio ?? s.bio,
        sector: sector ?? s.sector,
      );
      notifyListeners();
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    _core?.dispose();
    super.dispose();
  }
}

/// Durumu ağaca taşır.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope bulunamadı');
    return scope!.notifier!;
  }
}
