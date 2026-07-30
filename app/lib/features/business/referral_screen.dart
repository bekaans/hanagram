// Hanagram — Referans Sistemi
//
// Her kullanıcının 1 benzersiz kodu var, davet ettikleri gerçek listeden gelir.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hanagram_design/design.dart';
import '../../core/app_state.dart';
import '../../core/referral_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String? _code;
  List<Map<String, dynamic>> _referrals = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = AppScope.of(context).session?.userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final results = await Future.wait([
      ReferralService.getMyCode(userId),
      ReferralService.getMyReferrals(userId),
    ]);
    if (mounted) {
      setState(() {
        _code = results[0] as String?;
        _referrals = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final referrals = _referrals;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Referanslar', style: HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(HgSpace.lg),
        children: [
          // Üst bilgi kartı
          Container(
            padding: const EdgeInsets.all(HgSpace.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.violet.withValues(alpha: 0.15), c.blue.withValues(alpha: 0.10)],
              ),
              borderRadius: BorderRadius.circular(HgRadius.md),
              border: Border.all(color: c.violet.withValues(alpha: 0.25), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.gift, color: c.violet, size: 22),
                    const SizedBox(width: HgSpace.sm),
                    Text('Referans Programı', style: HgText.heading.copyWith(color: c.text, shadows: null)),
                  ],
                ),
                const SizedBox(height: HgSpace.md),
                _BenefitRow(
                  icon: CupertinoIcons.clock,
                  text: '1 Yıl Ücretsiz',
                  desc: 'Kayıt olduktan sonra 1 yıl boyunca ücretsiz',
                  c: c,
                ),
                const SizedBox(height: HgSpace.sm),
                _BenefitRow(
                  icon: CupertinoIcons.plus_circle,
                  text: 'Referans Başına +1 Ay',
                  desc: 'Her davet ettiğin kişi için 1 ay daha ücretsiz',
                  c: c,
                ),
                const SizedBox(height: HgSpace.sm),
                _BenefitRow(
                  icon: CupertinoIcons.money_dollar_circle,
                  text: 'Kalıcı Komisyon',
                  desc: 'Referanslarının her alışverişinden komisyon kazan',
                  c: c,
                ),
              ],
            ),
          ),
          const SizedBox(height: HgSpace.xl),

          // Referans kodu
          Text('Referans Kodun', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.md),
          Container(
            padding: const EdgeInsets.all(HgSpace.md),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(HgRadius.md),
              border: Border.all(color: c.violet.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kodun', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                      const SizedBox(height: 2),
                      Text(_isLoading ? '…' : (_code ?? '—'), style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: c.violet,
                        fontFamily: '.SF Pro Text', letterSpacing: 1,
                      )),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final code = _code;
                    if (code == null) return;
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kod kopyalandı!')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.violet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.doc_on_doc, size: 14, color: c.violet),
                        const SizedBox(width: 4),
                        Text('Kopyala', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: c.violet,
                        )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: HgSpace.lg),

          // Davet butonu
          BrandButton(
            label: 'Arkadaşını Davet Et',
            icon: CupertinoIcons.person_badge_plus,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Paylaşım ekranı yakında!')),
              );
            },
          ),
          const SizedBox(height: HgSpace.xl),

          // Referans listesi
          Text('Referanslarım (${referrals.length})', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.md),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (referrals.isEmpty)
            EmptyState(
              icon: CupertinoIcons.person_2,
              title: 'Henüz kimseyi davet etmedin',
              message: 'Kodunu paylaştığında burada görünecek.',
            )
          else
            for (final r in referrals)
              _ReferralCard(referral: r, c: c),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.text, required this.desc, required this.c});
  final IconData icon;
  final String text;
  final String desc;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c.violet),
        const SizedBox(width: HgSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
              Text(desc, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.referral, required this.c});
  final Map<String, dynamic> referral;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    final referred =
        (referral['referred'] as Map?)?.cast<String, dynamic>() ?? {};
    final name = referred['full_name'] as String? ?? '?';
    final username = referred['username'] as String? ?? '?';
    final createdAt = referral['created_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: HgSpace.sm),
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        children: [
          Avatar(name: name, size: 36, gradient: true),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                Text('@$username', style: HgText.caption.copyWith(color: c.textFaint, shadows: null)),
              ],
            ),
          ),
          Text(_formatDate(createdAt),
              style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
        ],
      ),
    );
  }

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.'
          '${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
