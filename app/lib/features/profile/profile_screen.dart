// Hanagram — profil ekranı (Supabase, SOLID: Orchestrator)
//
// Tüm profil widget'larını birleştirir. Canlı veri, yetki kontrolü,
// arama ve yol tarifi fonksiyonel.
// Sekmeli yapı: Profil + Yorumlar.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/connection_service.dart';
import '../../core/message_service.dart';
import '../../core/post_service.dart';
import '../../core/profile_service.dart';
import '../../core/referral_service.dart';
import '../../core/supabase_service.dart';
import '../../core/verification_service.dart';
import '../../core/utils.dart';
import 'package:hanagram_design/design.dart';
import '../settings/settings_screen.dart';
import '../messages/chat_detail_screen.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_stats.dart';
import 'widgets/profile_actions.dart';
import 'widgets/profile_directions.dart';
import 'widgets/profile_reviews.dart';
import 'widgets/profile_services_list.dart';
import 'widgets/referral_code_banner.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId, this.isOwnProfile = true});

  /// Diğer kullanıcının ID'si. null ise kendi profilimiz.
  final String? userId;

  /// Bu ekran kendi profilimiz mi?
  final bool isOwnProfile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  ProfileStatsData? _statsData;
  bool _isGranted = false;
  bool _isVerified = false;
  String? _referralCode;
  late TabController _tabCtrl;

  // Görüntülenen profilin bilgileri — kendi profilim ya da widget.userId
  // (handle) sahibinin gerçek verisi. `app.session` sadece KENDİ oturumumu
  // temsil eder, başkasının profilini görüntülerken kullanılmaz.
  String? _targetAuthId;
  String? _targetDbId;
  String _targetName = '';
  String _targetHandle = '';
  String _targetBio = '';
  String _targetAccountType = 'personal';
  bool _notFound = false;
  DateTime? _targetLastSeenAt;
  bool _targetShowOnlineStatus = true;

  bool get _isOwn => widget.isOwnProfile;

  /// Başkasının profilinde çevrimiçi/son görülme metni — sadece o kullanıcı
  /// "Çevrimiçi görünürlük" ayarını açık bıraktıysa gösterilir.
  String? get _onlineStatusText {
    if (_isOwn || !_targetShowOnlineStatus) return null;
    final lastSeen = _targetLastSeenAt;
    if (lastSeen == null) return null;
    final diff = DateTime.now().toUtc().difference(lastSeen.toUtc());
    if (diff.inMinutes < 5) return 'Çevrimiçi';
    if (diff.inMinutes < 60) return 'Son görülme: ${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return 'Son görülme: ${diff.inHours} saat önce';
    return 'Son görülme: ${diff.inDays} gün önce';
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final app = AppScope.of(context);

    if (_isOwn) {
      final s = app.session;
      if (s == null) return;
      _targetAuthId = SupabaseService.user?.id;
      _targetDbId = s.userId;
      _targetName = s.name;
      _targetHandle = s.handle;
      _targetBio = s.bio;
      _targetAccountType = s.accountType;
    } else {
      final handle = widget.userId;
      if (handle == null) return;
      final profile = await ProfileService.getPublicProfile(handle);
      if (profile == null) {
        if (mounted) setState(() => _notFound = true);
        return;
      }
      _targetAuthId = profile['auth_id'] as String?;
      _targetDbId = profile['id'] as String?;
      _targetName = profile['full_name'] as String? ?? '';
      _targetHandle = profile['username'] as String? ?? '';
      _targetBio = profile['bio'] as String? ?? '';
      _targetAccountType = profile['account_type'] as String? ?? 'personal';
      _targetLastSeenAt = DateTime.tryParse(profile['last_seen_at'] as String? ?? '');
      _targetShowOnlineStatus = profile['show_online_status'] as bool? ?? true;
    }

    final authId = _targetAuthId;
    final dbId = _targetDbId;
    if (authId == null || dbId == null) {
      if (mounted) setState(() => _notFound = true);
      return;
    }

    // Paralel olarak tüm profil verilerini çek
    final results = await Future.wait([
      ProfileService.getProfileStats(authId),
      VerificationService.isVerified(authId),
      ConnectionService.getMyConnections().catchError((_) => <Map<String, dynamic>>[]),
      if (_isOwn) ReferralService.getMyCode(dbId).catchError((_) => null),
    ]);

    final stats = results[0] as ProfileStatsData;
    final verified = results[1] as bool;
    final connections = results[2] as List<Map<String, dynamic>>;
    final granted = connections.isNotEmpty;
    final code = _isOwn ? results[3] as String? : null;

    if (mounted) {
      setState(() {
        _statsData = stats;
        _isVerified = verified;
        _isGranted = granted;
        _referralCode = code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final app = AppScope.of(context);
    if (app.session == null) return const SizedBox.shrink();
    if (_notFound) {
      return Center(
        child: EmptyState(
          icon: CupertinoIcons.person_crop_circle_badge_xmark,
          title: 'Kullanıcı bulunamadı',
          message: 'Bu profil artık mevcut değil.',
        ),
      );
    }
    if (_targetDbId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isBusiness = _targetAccountType == 'business';
    final isCreator = _targetAccountType == 'creator';
    final isPro = isBusiness || isCreator;
    final stats = _statsData;

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            children: [
              // ─── Sekme başlığı ───
              if (_isOwn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg),
                  child: Row(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const SettingsScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(HgSpace.sm),
                          decoration: BoxDecoration(
                            color: c.surfaceAlt.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(HgRadius.pill),
                          ),
                          child: Icon(CupertinoIcons.gear, size: 19, color: c.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Tab bar ───
              Container(
                padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: c.violet,
                  unselectedLabelColor: c.textMuted,
                  indicatorColor: c.violet,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: HgText.bodyStrong.copyWith(color: c.violet, shadows: null),
                  unselectedLabelStyle: HgText.body.copyWith(color: c.textMuted, shadows: null),
                  tabs: const [
                    Tab(text: 'Profil'),
                    Tab(text: 'Yorumlar'),
                  ],
                ),
              ),

              // ─── Sekme içeriği ───
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildProfileTab(c, app, isPro, stats),
                    _buildReviewsTab(c),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxWidth > HgBreak.tablet) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: content,
              ),
            );
          }
          return content;
        },
      ),
    );
  }

  Widget _buildProfileTab(HgColors c, AppState app, bool isPro, ProfileStatsData? stats) {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          HgSpace.lg,
          HgSpace.sm,
          HgSpace.lg,
          HgSpace.bottomPadding(context),
        ),
        children: [
          // ── Referans kodu (sadece kendi profilim) ──
          if (_isOwn && _referralCode != null) ...[
            ReferralCodeBanner(code: _referralCode!),
            const SizedBox(height: HgSpace.xl),
          ],

          // ── Profil başlığı ──
          ProfileHeader(
            name: _targetName,
            handle: _targetHandle,
            bio: _targetBio,
            isBusiness: isPro,
            isVerified: _isVerified,
          ),
          if (_onlineStatusText != null) ...[
            const SizedBox(height: HgSpace.xs),
            Center(
              child: Text(
                _onlineStatusText!,
                style: HgText.caption.copyWith(
                  color: _onlineStatusText == 'Çevrimiçi' ? c.success : c.textMuted,
                ),
              ),
            ),
          ],
          const SizedBox(height: HgSpace.xl),

          // ── İstatistikler ──
          ProfileStats(
            targetAuthId: _targetAuthId!,
            isOwner: _isOwn,
            isGranted: _isGranted,
          ),
          const SizedBox(height: HgSpace.xl),

          // ── Aksiyon butonları ──
          ProfileActions(
            onAction: _handleAction,
            phone: stats?.phone ?? '',
            address: stats?.address ?? '',
            latitude: stats?.latitude,
            longitude: stats?.longitude,
          ),
          const SizedBox(height: HgSpace.xl),

          if (isPro) ...[
            // ── Hizmetler ──
            ProfileServicesList(c: c),
            const SizedBox(height: HgSpace.xl),

            // ── Yol Tarifleri ──
            ProfileDirections(
              address: stats?.address ?? 'Adres eklenmemiş',
              latitude: stats?.latitude,
              longitude: stats?.longitude,
            ),
            const SizedBox(height: HgSpace.xl),

            // ── Portfolyo grid ──
            _PortfolioSection(c: c, authorId: _targetDbId!),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsTab(HgColors c) {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          HgSpace.lg,
          HgSpace.lg,
          HgSpace.lg,
          HgSpace.bottomPadding(context),
        ),
        children: [
          ProfileReviews(
            businessId: _targetDbId!,
            canWrite: !_isOwn,
            onWrote: _loadProfileData,
          ),
        ],
      ),
    );
  }

  void _handleAction(String action) {
    switch (action) {
      case 'message':
        if (_isOwn) {
          // Kendi profilimde → Mesajlar sekmesine git
          AppScope.of(context).tabController.value = 3; // Mesajlar index
        } else {
          // Başka kullanıcının profili → gerçek DM'i bul/oluştur
          _openDm();
        }
        break;
      case 'appointment':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Randevu alma ekranı yakında!')),
        );
        break;
    }
  }

  Future<void> _openDm() async {
    final targetId = _targetDbId;
    if (targetId == null) return;
    final convId = await MessageService.findOrCreateDm(targetId);
    if (!mounted) return;

    if (convId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet açılamadı, tekrar deneyin.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          threadId: convId,
          otherName: _targetName,
        ),
      ),
    );
  }
}

// ─── Portfolyo grid ───

class _PortfolioSection extends StatefulWidget {
  const _PortfolioSection({required this.c, required this.authorId});
  final HgColors c;
  final String authorId;

  @override
  State<_PortfolioSection> createState() => _PortfolioSectionState();
}

class _PortfolioSectionState extends State<_PortfolioSection> {
  List<Map<String, dynamic>> _items = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await PostService.getPortfolio(authorId: widget.authorId);
    if (!mounted) return;
    setState(() {
      _items = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.photo_on_rectangle,
                size: 16, color: c.violet),
            const SizedBox(width: HgSpace.sm),
            Text('Portfolyo',
                style: HgText.heading
                    .copyWith(color: c.text, shadows: null)),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        Builder(
          builder: (ctx) {
            final w = MediaQuery.sizeOf(ctx).width;
            final cols = w >= HgBreak.desktop
                ? 5
                : w >= HgBreak.tablet
                    ? 4
                    : 3;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.85,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                final mediaUrl = item['mediaUrl'] as String? ?? '';
                final isVideo = item['mediaType'] == 'video';
                final colors = [
                  [c.violet, c.blue],
                  [c.coral, c.violet],
                  [c.blue, c.success],
                  [c.warning, c.coral],
                  [c.success, c.blue],
                  [c.violet, c.coral],
                ];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(HgRadius.sm),
                  child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors[i % colors.length],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.circular(HgRadius.sm),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (mediaUrl.isNotEmpty && !isVideo)
                        Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(CupertinoIcons.photo,
                                size: 24,
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                        )
                      else
                        Center(
                          child: Icon(
                            isVideo
                                ? CupertinoIcons.video_camera
                                : CupertinoIcons.photo,
                            size: 24,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      Positioned(
                        bottom: 4,
                        left: 5,
                        child: Row(
                          children: [
                            const Icon(
                                CupertinoIcons.heart_fill,
                                size: 10,
                                color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                                fmtCount((item['likes'] as num?)?.toInt() ?? 0),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
