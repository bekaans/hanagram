// Hanagram — Üyelik Paketleri
//
// Gold, Platinum, Diamond aylık paketler. Reels etkileşim desteği sağlar.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Paketler', style: HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(HgSpace.lg),
        children: [
          // Üst bilgi
          Container(
            padding: const EdgeInsets.all(HgSpace.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.violet.withValues(alpha: 0.12), c.blue.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(HgRadius.md),
              border: Border.all(color: c.violet.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.star_fill, color: c.warning, size: 20),
                    const SizedBox(width: HgSpace.sm),
                    Text('Reels Etkileşim Desteği', style: HgText.heading.copyWith(color: c.text, shadows: null)),
                  ],
                ),
                const SizedBox(height: HgSpace.sm),
                Text(
                  'Paketinle reels, post veya hikayelerine etkileşim desteği al, '
                  'içeriklerini daha geniş kitlelere ulaştır.',
                  style: HgText.caption.copyWith(color: c.textMuted, shadows: null),
                ),
              ],
            ),
          ),
          const SizedBox(height: HgSpace.xl),

          // Paketler
          _PackageCard(
            name: 'Gold',
            price: '299',
            color: const Color(0xFFFFB020),
            gradient: [const Color(0xFFFFB020), const Color(0xFFE09000)],
            features: [
              'Aylık 5.000 görüntülenme desteği',
              '1 Reels Boost (1x)',
              'Profil rozeti: Gold',
              'Öncelikli destek',
            ],
            c: c,
          ),
          const SizedBox(height: HgSpace.md),

          _PackageCard(
            name: 'Platinum',
            price: '599',
            color: const Color(0xFFB0B8C8),
            gradient: [const Color(0xFFB0B8C8), const Color(0xFF8090A8)],
            features: [
              'Aylık 15.000 görüntülenme desteği',
              '3 Reels Boost (2x)',
              'Profil rozeti: Platinum',
              'Hedef kitle analizi',
              'Öncelikli destek',
            ],
            featured: true,
            c: c,
          ),
          const SizedBox(height: HgSpace.md),

          _PackageCard(
            name: 'Diamond',
            price: '999',
            color: c.violet,
            gradient: [c.violet, c.blue],
            features: [
              'Aylık 50.000 görüntülenme desteği',
              'Sınırsız Reels Boost',
              'Profil rozeti: Diamond',
              'Gelişmiş hedef kitle analizi',
              'Kişisel hesap yöneticisi',
              'Öncelikli destek',
            ],
            c: c,
          ),
          const SizedBox(height: HgSpace.xl),

          // CTA Drag & Drop bölümü
          _CTASection(c: c),
        ],
      ),
    );
  }
}

// ─── Paket Kartı ───

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.name,
    required this.price,
    required this.color,
    required this.gradient,
    required this.features,
    required this.c,
    this.featured = false,
  });

  final String name;
  final String price;
  final Color color;
  final List<Color> gradient;
  final List<String> features;
  final HgColors c;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HgSpace.lg),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(
          color: featured ? color : c.border.withValues(alpha: 0.5),
          width: featured ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rozet
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(name, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white,
                )),
              ),
              if (featured) ...[
                const SizedBox(width: HgSpace.sm),
                HgChip(label: 'POPÜLER', color: color),
              ],
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₺$price', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color,
                    fontFamily: '.SF Pro Text',
                  )),
                  Text('/ay', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                ],
              ),
            ],
          ),
          const SizedBox(height: HgSpace.md),
          Divider(height: 1, thickness: 0.5, color: c.border.withValues(alpha: 0.4)),
          const SizedBox(height: HgSpace.md),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: color),
                  const SizedBox(width: HgSpace.sm),
                  Expanded(child: Text(f, style: HgText.caption.copyWith(color: c.text, shadows: null))),
                ],
              ),
            ),
          const SizedBox(height: HgSpace.md),
          BrandButton(
            label: 'Paketi Satın Al',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name paketi yakında aktif olacak!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── CTA Sürükle-Bırak Bölümü ───

class _CTASection extends StatefulWidget {
  const _CTASection({required this.c});
  final HgColors c;

  @override
  State<_CTASection> createState() => _CTASectionState();
}

class _CTASectionState extends State<_CTASection> {
  // Sürüklenebilir CTA ikonları
  final List<_CTAItem> _availableCTAs = [
    _CTAItem(icon: CupertinoIcons.cart, label: 'Satın Al'),
    _CTAItem(icon: CupertinoIcons.chat_bubble, label: 'Mesaj At'),
    _CTAItem(icon: CupertinoIcons.phone, label: 'Ara'),
    _CTAItem(icon: CupertinoIcons.location, label: 'Konum'),
    _CTAItem(icon: CupertinoIcons.link, label: 'Bağlantı'),
    _CTAItem(icon: CupertinoIcons.bookmark, label: 'Kaydet'),
  ];

  // Seçili CTA'lar (içerik köşelerine yerleştirilen)
  final List<_CTAItem?> _placedCTAs = [null, null, null, null]; // Sol üst, sağ üst, sol alt, sağ alt
  int _selectedSlot = -1;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.cursor_rays, size: 16, color: c.violet),
            const SizedBox(width: HgSpace.sm),
            Text('CTA Butonları', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          ],
        ),
        const SizedBox(height: HgSpace.sm),
        Text(
          'İçeriklerinin köşelerine CTA butonları sürükle. '
          'İzleyiciler satın alabilir, mesaj atabilir veya arayabilir.',
          style: HgText.caption.copyWith(color: c.textMuted, shadows: null),
        ),
        const SizedBox(height: HgSpace.lg),

        // İçerik önizleme alanı
        Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.violet.withValues(alpha: 0.15), c.blue.withValues(alpha: 0.10)],
            ),
            borderRadius: BorderRadius.circular(HgRadius.md),
            border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Stack(
            children: [
              // Merkez
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.play_rectangle, size: 40, color: c.textMuted),
                    const SizedBox(height: HgSpace.sm),
                    Text('İçerik Önizleme', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                  ],
                ),
              ),
              // Köşe slotları
              for (var i = 0; i < 4; i++)
                Positioned(
                  top: i < 2 ? 8 : null,
                  bottom: i >= 2 ? 8 : null,
                  left: i % 2 == 0 ? 8 : null,
                  right: i % 2 == 1 ? 8 : null,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSlot = _selectedSlot == i ? -1 : i),
                    child: _placedCTAs[i] != null
                        ? _PlacedCTABadge(
                            cta: _placedCTAs[i]!,
                            c: c,
                            onRemove: () => setState(() {
                              _availableCTAs.add(_placedCTAs[i]!);
                              _placedCTAs[i] = null;
                            }),
                          )
                        : Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _selectedSlot == i
                                  ? c.violet.withValues(alpha: 0.2)
                                  : c.surface.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedSlot == i ? c.violet : c.border,
                                width: _selectedSlot == i ? 1.5 : 0.5,
                              ),
                            ),
                            child: Icon(CupertinoIcons.plus, size: 16,
                                color: _selectedSlot == i ? c.violet : c.textMuted),
                          ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: HgSpace.lg),

        // Kullanılabilir CTA'lar
        Text('Sürüklenebilir Butonlar', style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
        const SizedBox(height: HgSpace.md),
        Wrap(
          spacing: HgSpace.sm,
          runSpacing: HgSpace.sm,
          children: _availableCTAs.map((cta) => Draggable<_CTAItem>(
            data: cta,
            onDragStarted: () {},
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.violet,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: c.violet.withValues(alpha: 0.3), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cta.icon, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(cta.label, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white,
                    )),
                  ],
                ),
              ),
            ),
            childWhenDragging: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceAlt.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cta.icon, size: 14, color: c.textFaint),
                  const SizedBox(width: 4),
                  Text(cta.label, style: TextStyle(
                    fontSize: 12, color: c.textFaint,
                  )),
                ],
              ),
            ),
            child: GestureDetector(
              onTap: () {
                // Slot seçiliyse oraya yerleştir
                if (_selectedSlot >= 0 && _placedCTAs[_selectedSlot] == null) {
                  setState(() {
                    _placedCTAs[_selectedSlot] = cta;
                    _availableCTAs.remove(cta);
                    _selectedSlot = -1;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cta.icon, size: 14, color: c.violet),
                    const SizedBox(width: 4),
                    Text(cta.label, style: HgText.caption.copyWith(color: c.text, shadows: null)),
                  ],
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: HgSpace.xl),
      ],
    );
  }
}

class _CTAItem {
  _CTAItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _PlacedCTABadge extends StatelessWidget {
  const _PlacedCTABadge({required this.cta, required this.c, required this.onRemove});
  final _CTAItem cta;
  final HgColors c;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.violet, c.blue]),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: c.violet.withValues(alpha: 0.3), blurRadius: 6)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cta.icon, size: 12, color: Colors.white),
            const SizedBox(width: 3),
            Text(cta.label, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white,
            )),
          ],
        ),
      ),
    );
  }
}
