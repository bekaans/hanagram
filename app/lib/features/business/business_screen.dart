// Hanagram — profesyonel panel (işletme / içerik üreticisi)
//
// İş akışı, görev yönetimi, paketler, referans sistemi.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import '../connections/connections_screen.dart';
import 'appointment_screen.dart';
import 'calendar_view.dart';
import 'customer_screen.dart';
import 'product_screen.dart';
import 'media_screen.dart';
import 'sale_screen.dart';
import 'task_screen.dart';
import 'accounting_screen.dart';
import 'packages_screen.dart';
import 'referral_screen.dart';

class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final app = AppScope.of(context);
    if (app.session == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.lg, HgSpace.lg, HgSpace.bottomPadding(context)),
        children: [
          Row(
            children: [
              Text('Yönetim', style: HgText.title.copyWith(color: c.text, shadows: null)),
            ],
          ),
          const SizedBox(height: HgSpace.xl),

          // ——— Hızlı özet ———
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Görüntülenme',
                  value: '12.4K',
                  icon: CupertinoIcons.eye,
                  color: c.violet,
                ),
              ),
              const SizedBox(width: HgSpace.md),
              Expanded(
                child: _Stat(
                  label: 'Etkileşim',
                  value: '8.7K',
                  icon: CupertinoIcons.heart,
                  color: c.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: HgSpace.xl),

          // ——— İş Akışı & Görev Yönetimi ———
          _SectionHeader(
            icon: CupertinoIcons.checkmark_square,
            title: 'İş Akışı',
            subtitle: 'Görevleri yönet, çalışanları davet et',
            c: c,
          ),
          const SizedBox(height: HgSpace.md),
          _Tool(
            icon: CupertinoIcons.list_bullet,
            title: 'Görev Yönetimi',
            desc: 'Çalışanlara görev ata, ilerlemeyi takip et',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TaskScreen()),
            ),
          ),
          _Tool(
            icon: CupertinoIcons.person_2,
            title: 'Bağlantılar',
            desc: 'Arkadaş ve çalışan ekle, istekleri yönet',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
            ),
          ),
          _Tool(
            icon: CupertinoIcons.calendar,
            title: 'Takvim',
            desc: 'Günlük görev ve randevu görünümü',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalendarView()),
            ),
          ),
          const SizedBox(height: HgSpace.xl),

          // ——— İşletme Araçları ———
          _SectionHeader(
            icon: CupertinoIcons.wrench,
            title: 'İşletme araçları',
            subtitle: 'İşletmeni yönet',
            c: c,
          ),
          const SizedBox(height: HgSpace.md),

          _Tool(
            icon: CupertinoIcons.calendar,
            title: 'Randevular',
            desc: 'Slot takvimi, müşteri talepleri, onay',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppointmentScreen()),
            ),
          ),
          _Tool(
            icon: CupertinoIcons.person_2,
            title: 'Müşteri portföyü',
            desc: 'Gizli CRM — sen paylaşmadıkça kimse göremez',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerScreen()),
            ),
          ),
          _Tool(
            icon: CupertinoIcons.bag,
            title: 'Ürünler',
            desc: 'Ürün kataloğu ve fiyat yönetimi',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductScreen()),
            ),
          ),
          _Tool(
            icon: CupertinoIcons.doc_text,
            title: 'Satış ve ciro',
            desc: 'Satış kayıtları, gelir-gider, raporlar',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SaleScreen()),
            ),
          ),
          _Tool(
            icon: CupertinoIcons.money_dollar_circle,
            title: 'Muhasebe',
            desc: 'Gelir-gider takibi, aylık raporlar, istatistikler',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountingScreen()),
            ),
          ),
          _Tool(
            icon: CupertinoIcons.photo_camera,
            title: 'Medya galerisi',
            desc: 'Fotoğraf ve video yönetimi',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MediaScreen()),
            ),
          ),
          const SizedBox(height: HgSpace.xl),

          // ——— Üyelik & Paketler ———
          _SectionHeader(
            icon: CupertinoIcons.star,
            title: 'Paketler',
            subtitle: 'Reels etkileşim desteği al',
            c: c,
          ),
          const SizedBox(height: HgSpace.md),
          _Tool(
            icon: CupertinoIcons.star_circle,
            title: 'Gold / Platinum / Diamond',
            desc: 'Aylık paketlerle içeriklerini öne çıkar',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PackagesScreen()),
            ),
          ),
          const SizedBox(height: HgSpace.xl),

          // ——— Referans Sistemi ———
          _SectionHeader(
            icon: CupertinoIcons.person_3,
            title: 'Referanslar',
            subtitle: 'Davet et, kazan, komisyon al',
            c: c,
          ),
          const SizedBox(height: HgSpace.md),
          _Tool(
            icon: CupertinoIcons.gift,
            title: 'Referans Programı',
            desc: '1 yıl ücretsiz + komisyon kazan',
            ready: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bölüm başlığı ───

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.subtitle, required this.c});
  final IconData icon;
  final String title;
  final String subtitle;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: c.violet.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: c.violet),
        ),
        const SizedBox(width: HgSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HgText.heading.copyWith(color: c.text, shadows: null)),
              Text(subtitle, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── İstatistik kartı ───

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return HgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(HgRadius.sm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: HgSpace.md),
          Text(value, style: HgText.display.copyWith(color: c.text, fontSize: 26, shadows: null)),
          Text(label, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
        ],
      ),
    );
  }
}

// ─── Araç kartı ───

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.title,
    required this.desc,
    required this.ready,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool ready;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: HgSpace.sm),
      child: HgCard(
        padding: const EdgeInsets.all(HgSpace.md),
        onTap: ready ? onTap : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(HgRadius.md),
              ),
              child: Icon(icon, size: 19, color: c.textMuted),
            ),
            const SizedBox(width: HgSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                  Text(desc, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                ],
              ),
            ),
            if (ready)
              Icon(CupertinoIcons.chevron_right, size: 16, color: c.textFaint)
            else
              HgChip(label: 'YAKINDA', color: c.warning),
          ],
        ),
      ),
    );
  }
}
