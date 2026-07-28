// Hanagram — uygulama durumu
//
// Yalnızca SUNUM durumu tutar (hangi sekme açık, yükleniyor mu, elde hangi liste var).
// İş kuralı servislerde: FeedService, InviteService, ProfileService.
import 'web_compat.dart';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hanagram_design/design.dart';
import 'feed_service.dart';
import 'invite_service.dart';
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

enum CoreStatus { starting, ready, failed }

class AppState extends ChangeNotifier {
  HanagramCore? _core;
  CoreStatus status = CoreStatus.starting;
  String? failureDetail;

  Session? session;
  bool busy = false;

  /// Alt bar sekmeleri arası geçiş için kontrolcü.
  /// Profil → Mesajlar gibi ekranlar arası geçişlerde kullanılır.
  final ValueNotifier<int> tabController = ValueNotifier(0);

  // Servisler — boot() sonrasında geçerli.
  late final FeedService feedService;
  late final InviteService inviteService;

  // Geriye uyumluluk: doğrudan erişim (ekranlar değiştirmeden çalışmaya devam eder).
  List<FeedItem> get feed => feedService.feed;
  set feed(List<FeedItem> v) => feedService.feed = v;
  List<FeedItem> get discover => feedService.discover;
  set discover(List<FeedItem> v) => feedService.discover = v;
  double get profileConfidence => feedService.profileConfidence;
  List<String> get myInviteCodes => inviteService.myInviteCodes;

  HanagramCore get core {
    final c = _core;
    if (c == null) throw CoreUnavailable('başlatılmadı');
    return c;
  }

  String get coreVersion => _core?.version ?? '—';

  Future<void> boot() async {
    try {
      String dir = '';
      try {
        final d = await getApplicationSupportDirectory();
        dir = '${d.path}${pathSeparator}hanagram';
      } catch (_) {
        dir = '';
      }
      _core = HanagramCore.start(dir);

      // Servisleri oluştur.
      feedService = FeedService(_core!, () => notifyListeners());
      inviteService = InviteService(_core!);

      inviteService.seedFirstRunIfNeeded();

      // Supabase oturumunu geri yükle
      await _restoreSession();

      status = CoreStatus.ready;
    } catch (e) {
      status = CoreStatus.failed;
      failureDetail = e.toString();
    }
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

  // ─── Geriye uyumluluk API'si — ekranlar bu metotları çağırıyor ───

  ({bool valid, String code, String invitedBy}) checkInvite(String raw) =>
      inviteService.checkInvite(raw);

  String? redeem(String code, String name, String accountType) {
    final result = inviteService.redeem(code, name, accountType);
    if (result == null) return 'Geçersiz davet kodu';

    session = Session.fromJson((result['user'] as Map).cast<String, dynamic>());
    membership = (result['membership'] as Map).cast<String, dynamic>();
    notifyListeners();

    // Supabase'de de profil oluştur (arka planda)
    _syncToSupabase(code, name, accountType);

    return null;
  }

  /// Yerel kayıt sonrası Supabase'i senkronize et.
  Future<void> _syncToSupabase(String code, String name, String accountType) async {
    try {
      final authUser = SupabaseService.user;
      if (authUser == null) return;

      await ReferralService.createProfile(
        authId: authUser.id,
        username: name.toLowerCase().replaceAll(' ', ''),
        fullName: name,
        accountType: accountType,
        referralCode: code,
      );

      // Referans kodu v2: sınırsız kullanım, redeemCode kaldırıldı
    } catch (_) {
      // Senkronizasyon başarısız — yerel veriler korunur
    }
  }

  Map<String, dynamic>? membership;

  /// Dışarıdan durum değişikliği bildir (ör: kayıt sonrası session güncelleme).
  void updateSession(Session s) {
    session = s;
    notifyListeners();
  }

  Future<void> loadFeed({String mode = 'foryou'}) async {
    final s = session;
    if (s == null) return;
    busy = true;
    notifyListeners();
    feedService.loadFeed(s.userId, mode: mode);
    busy = false;
    notifyListeners();
  }

  Future<void> loadDiscover({String query = ''}) async {
    final s = session;
    if (s == null) return;
    feedService.loadDiscover(s.userId, query: query);
    notifyListeners();
  }

  void signal(String itemId, String kind, {int dwellMs = 0}) {
    final s = session;
    if (s == null) return;
    feedService.signal(s.userId, itemId, kind, dwellMs: dwellMs);
  }

  void createPost(String caption, List<String> topics) {
    final s = session;
    if (s == null) return;
    feedService.createPost(s.userId, caption, topics);
    loadFeed();
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
