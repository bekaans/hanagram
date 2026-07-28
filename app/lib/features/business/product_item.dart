// Hanagram — ürün modeli ve kart görünümü.
//
// customer_item.dart ile aynı kalıp: model ve kart aynı dosyada.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';

class ProductItem {
  final String id;
  final String businessId;
  final String name;
  final String description;
  final int priceKurus;
  final String category;
  final bool active;
  final int createdAt;
  final int updatedAt;

  const ProductItem({
    required this.id,
    required this.businessId,
    required this.name,
    this.description = '',
    this.priceKurus = 0,
    this.category = '',
    this.active = true,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory ProductItem.fromJson(Map<String, dynamic> j) {
    return ProductItem(
      id: j['id'] as String? ?? '',
      businessId: j['businessId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      priceKurus: (j['priceKurus'] as num?)?.toInt() ?? 0,
      category: j['category'] as String? ?? '',
      active: j['active'] as bool? ?? true,
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tek ürün satırı. `onTap` düzenleme, `onEdit` düzenleme.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onEdit,
  });

  final ProductItem product;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final p = product;

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: HgText.bodyStrong.copyWith(color: c.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: HgSpace.sm),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: c.textMuted),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (p.category.isNotEmpty) ...[
            const SizedBox(height: HgSpace.xs),
            HgChip(label: p.category, color: c.blue, filled: false),
          ],
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: HgSpace.xs),
            Text(
              p.description,
              style: HgText.small.copyWith(color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: HgSpace.sm),
          Row(
            children: [
              Text(
                formatCurrency(p.priceKurus),
                style: HgText.bodyStrong.copyWith(color: c.success),
              ),
              const Spacer(),
              if (!p.active)
                HgChip(label: 'Pasif', color: c.textFaint, filled: false),
            ],
          ),
        ],
      ),
    );
  }
}
