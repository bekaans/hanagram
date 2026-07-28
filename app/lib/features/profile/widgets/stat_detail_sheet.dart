// Hanagram — istatistik detay sayfası
//
// Seçilen istatistiğin detay listesini gösterir.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class StatDetailSheet extends StatelessWidget {
  const StatDetailSheet({super.key, required this.statKey});
  final String statKey;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final data = _sampleData[statKey] ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Tutamaç
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              // Başlık
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: HgSpace.sm),
                child: Row(
                  children: [
                    Text(_titleFor(statKey), style: HgText.heading.copyWith(color: c.text, shadows: null)),
                    const Spacer(),
                    Text('${data.length} kayıt', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Liste
              Expanded(
                child: data.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.tray, size: 40, color: c.textFaint),
                            const SizedBox(height: HgSpace.md),
                            Text('Henüz kayıt yok', style: HgText.body.copyWith(color: c.textMuted, shadows: null)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: HgSpace.sm),
                        itemCount: data.length,
                        itemBuilder: (context, i) {
                          final item = data[i];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: 3),
                            padding: const EdgeInsets.all(HgSpace.md),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(HgRadius.sm),
                            ),
                            child: Row(
                              children: [
                                Avatar(name: item['name'] ?? '', size: 36, gradient: true),
                                const SizedBox(width: HgSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] ?? '', style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                                      Text(item['detail'] ?? '', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                                    ],
                                  ),
                                ),
                                Text(item['date'] ?? '', style: HgText.caption.copyWith(color: c.textFaint, shadows: null)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _titleFor(String key) {
    switch (key) {
      case 'satislar': return 'Satış Detayları';
      case 'randevular': return 'Randevu Detayları';
      case 'takipciler': return 'Takipçi Detayları';
      case 'begeniler': return 'Beğeni Detayları';
      case 'urunler': return 'Ürün Detayları';
      case 'favoriler': return 'Favori Detayları';
      default: return 'Detay';
    }
  }

  static final _sampleData = {
    'satislar': [
      {'name': 'Elif Demir', 'detail': 'Lazer epilasyon - 3 sean', 'date': '25 Tem'},
      {'name': 'Can Yıldız', 'detail': 'Saç botoksu - tek seans', 'date': '24 Tem'},
      {'name': 'Selin Kaya', 'detail': 'Hydrafacial - 4 sean', 'date': '22 Tem'},
      {'name': 'Merve Öz', 'detail': 'PRP - 3 sean', 'date': '20 Tem'},
    ],
    'randevular': [
      {'name': 'Can Yıldız', 'detail': 'Saç boyama', 'date': '26 Tem, 14:00'},
      {'name': 'Ayşe Yılmaz', 'detail': 'Manikür', 'date': '26 Tem, 15:30'},
      {'name': 'Zeynep Demir', 'detail': 'Makyaj prova', 'date': '27 Tem, 10:00'},
    ],
    'takipciler': [
      {'name': 'Selin Kaya', 'detail': '@selinkaya', 'date': 'Takip etti'},
      {'name': 'Merve Öz', 'detail': '@merveoz', 'date': 'Takip etti'},
      {'name': 'Ali Veli', 'detail': '@aliveli', 'date': 'Takip etti'},
    ],
    'begeniler': [
      {'name': 'Merve Öz', 'detail': 'Reel beğenisi', 'date': '2 saat önce'},
      {'name': 'Can Yıldız', 'detail': 'Post beğenisi', 'date': '5 saat önce'},
    ],
    'urunler': [
      {'name': 'Lazer Paketi - 6 Seans', 'detail': '₺12,000', 'date': '12 adet'},
      {'name': 'Hydrafacial Set', 'detail': '₺8,000', 'date': '8 adet'},
    ],
    'favoriler': [
      {'name': 'Elif Demir', 'detail': 'Lazer epilasyon', 'date': 'Favorilere eklendi'},
      {'name': 'Ayşe Yılmaz', 'detail': 'Cilt bakımı', 'date': 'Favorilere eklendi'},
      {'name': 'Zeynep Kaya', 'detail': 'Saç botoksu', 'date': 'Favorilere eklendi'},
    ],
  };
}
