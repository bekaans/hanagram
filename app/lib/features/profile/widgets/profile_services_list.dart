// Hanagram — hizmet listesi bileşeni
//
// Sütun sütun görünüm: kategoriler yan yana, her biri dikey liste.
// Boyutlar küçük, hepsi bir satırda.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../models/service_model.dart';

/// Profil hizmet listesi — sütun sütun görünüm.
class ProfileServicesList extends StatelessWidget {
  const ProfileServicesList({super.key, required this.c});

  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category_outlined, size: 16, color: c.violet),
            const SizedBox(width: HgSpace.sm),
            Text('Hizmetler', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        // Sütun sütun görünüm — yatay scroll
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: HgSpace.sm),
            itemCount: ServiceCategory.sampleCategories.length,
            separatorBuilder: (a, b) => const SizedBox(width: HgSpace.sm),
            itemBuilder: (context, i) {
              final cat = ServiceCategory.sampleCategories[i];
              return _ServiceColumn(category: cat, c: c);
            },
          ),
        ),
      ],
    );
  }
}

/// Tek bir hizmet sütunu — kategori başlığı + altta dikey hizmet kartları.
class _ServiceColumn extends StatelessWidget {
  const _ServiceColumn({required this.category, required this.c});
  final ServiceCategory category;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    final colors = category.gradientColors.map((hex) => Color(hex)).toList();

    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kategori başlığı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              category.name,
              style: const TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          // Hizmet kartları — dikey liste
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: category.services.length,
              separatorBuilder: (a, b) => const SizedBox(height: 3),
              itemBuilder: (context, j) {
                final service = category.services[j];
                return _SmallServiceCard(service: service, color: colors.first, c: c);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Küçük hizmet kartı — başlık + fiyat + buton.
class _SmallServiceCard extends StatelessWidget {
  const _SmallServiceCard({required this.service, required this.color, required this.c});
  final ServiceItem service;
  final Color color;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.name,
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            service.description,
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 9,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  service.price,
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${service.name} randevusu yakında!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Randevu',
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
