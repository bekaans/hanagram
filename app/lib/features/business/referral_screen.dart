// Hanagram — Referans Sistemi
//
// 1 yıl ücretsiz + referans başına 1 ay + kalıcı komisyon.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hanagram_design/design.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    // Örnek veriler
    final referrals = [
      _Referral(name: 'Elif Demir', date: '15 Tem 2026', status: 'Aktif', earned: '₺45'),
      _Referral(name: 'Can Yıldız', date: '20 Haz 2026', status: 'Aktif', earned: '₺30'),
      _Referral(name: 'Selin Kaya', date: '5 Haz 2026', status: 'Kayıtlı', earned: '₺15'),
    ];

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
                      Text('HANAGRAM-KAAN', style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: c.violet,
                        fontFamily: '.SF Pro Text', letterSpacing: 1,
                      )),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: 'HANAGRAM-KAAN'));
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

          // Bakiye
          Row(
            children: [
              Text('Kazançlarım', style: HgText.heading.copyWith(color: c.text, shadows: null)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.success, const Color(0xFF00C853)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('₺90', style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white,
                  fontFamily: '.SF Pro Text',
                )),
              ),
            ],
          ),
          const SizedBox(height: HgSpace.sm),
          Text('Hesap bakiyenize eklenecek tutar', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
          const SizedBox(height: HgSpace.xl),

          // Referans listesi
          Text('Referanslarım (${referrals.length})', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.md),
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

class _Referral {
  _Referral({required this.name, required this.date, required this.status, required this.earned});
  final String name;
  final String date;
  final String status;
  final String earned;
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.referral, required this.c});
  final _Referral referral;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    final isActive = referral.status == 'Aktif';
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
          // Avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isActive
                  ? [c.violet, c.blue]
                  : [c.textMuted, c.textFaint]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(referral.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().substring(0, 2.clamp(0, referral.name.length)),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(referral.name, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                Text(referral.date, style: HgText.caption.copyWith(color: c.textFaint, shadows: null)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(referral.earned, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: c.success,
                fontFamily: '.SF Pro Text',
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? c.success.withValues(alpha: 0.12) : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(referral.status, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: isActive ? c.success : c.textMuted,
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
