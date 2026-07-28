// Hanagram — profil ekranı (Supabase, SOLID: Orchestrator)
//
// Tüm profil widget'larını birleştirir. Canlı veri, yetki kontrolü,
// arama ve yol tarifi fonksiyonel.
// Sekmeli yapı: Profil + Yorumlar.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/connection_service.dart';
import '../../core/profile_service.dart';
import '../../core/referral_service.dart';
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

  bool get _isOwn => widget.isOwnProfile;

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
    final s = app.session;
    if (s == null) return;

    // Paralel olarak tüm profil verilerini çek
    final results = await Future.wait([
      ProfileService.getProfileStats(s.userId),
      VerificationService.isVerified(s.userId),
      ConnectionService.getMyConnections().catchError((_) => <Map<String, dynamic>>[]),
      if (_isOwn) ReferralService.getMyCode(s.userId).catchError((_) => null),
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
    final s = app.session;
    if (s == null) return const SizedBox.shrink();

    final isBusiness = s.accountType == 'business';
    final isCreator = s.accountType == 'creator';
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
              if (_isOwn)
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
                child: _isOwn
                    ? TabBarView(
                        controller: _tabCtrl,
                        children: [
                          _buildProfileTab(c, app, s, isPro, stats),
                          _buildReviewsTab(c),
                        ],
                      )
                    : _buildProfileTab(c, app, s, isPro, stats),
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

  Widget _buildProfileTab(HgColors c, AppState app, dynamic s, bool isPro, ProfileStatsData? stats) {
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
            name: s.name,
            handle: s.handle,
            bio: s.bio,
            isBusiness: isPro,
            isVerified: _isVerified,
          ),
          const SizedBox(height: HgSpace.xl),

          // ── İstatistikler ──
          ProfileStats(
            targetAuthId: s.userId,
            isOwner: _isOwn,
            isGranted: _isGranted,
          ),
          const SizedBox(height: HgSpace.xl),

          // ── Aksiyon butonları ──
          ProfileActions(
            onAction: (action) => _handleAction(context, action, s),
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
            _PortfolioSection(c: c),
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
            onAction: (action) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Yorum yazma yetkisi: sadece randevu sahipleri!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action, dynamic s) {
    switch (action) {
      case 'message':
        if (_isOwn) {
          // Kendi profilimde → Mesajlar sekmesine git
          final app = AppScope.of(context);
          app.tabController.value = 3; // Mesajlar index
        } else {
          // Başka kullanıcının profili → DM aç
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatDetailScreen(
                threadId: 'dm_${widget.userId}',
                otherName: s.name,
              ),
            ),
          );
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
}

// ─── Portfolyo grid ───

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({required this.c});
  final HgColors c;

  @override
  Widget build(BuildContext context) {
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
              itemCount: 6,
              itemBuilder: (context, i) {
                final colors = [
                  [c.violet, c.blue],
                  [c.coral, c.violet],
                  [c.blue, c.success],
                  [c.warning, c.coral],
                  [c.success, c.blue],
                  [c.violet, c.coral],
                ];
                return Container(
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
                    children: [
                      Center(
                        child: Icon(
                          [
                            CupertinoIcons.video_camera,
                            CupertinoIcons.camera,
                            CupertinoIcons.speaker_2,
                            CupertinoIcons.music_mic,
                            CupertinoIcons.paintbrush,
                            CupertinoIcons.wand_stars
                          ][i % 6],
                          size: 24,
                          color: Colors.white
                              .withValues(alpha: 0.4),
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
                                fmtCount([
                                  45, 128, 67, 234, 89, 156
                                ][i]),
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
                );
              },
            );
          },
        ),
      ],
    );
  }
}
