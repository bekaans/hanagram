// Hanagram — satış modeli ve kart görünümü.
//
// customer_item.dart kalıbına göre.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';

class SaleItem {
  final String id;
  final String businessId;
  final String customerId;
  final String customerName;
  final List<SaleLineItem> items;
  final int totalKurus;
  final String paymentMethod;
  final String note;
  final String source;
  final int createdAt;

  const SaleItem({
    required this.id,
    required this.businessId,
    this.customerId = '',
    this.customerName = '',
    this.items = const [],
    this.totalKurus = 0,
    this.paymentMethod = 'cash',
    this.note = '',
    this.source = 'direct',
    this.createdAt = 0,
  });

  factory SaleItem.fromJson(Map<String, dynamic> j) {
    List<SaleLineItem> lineItems = const [];
    final itemsData = j['items'];
    if (itemsData is List) {
      lineItems = itemsData
          .map((e) => SaleLineItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }

    return SaleItem(
      id: j['id'] as String? ?? '',
      businessId: j['businessId'] as String? ?? '',
      customerId: j['customerId'] as String? ?? '',
      customerName: j['customerName'] as String? ?? '',
      items: lineItems,
      totalKurus: (j['totalKurus'] as num?)?.toInt() ?? 0,
      paymentMethod: j['paymentMethod'] as String? ?? 'cash',
      note: j['note'] as String? ?? '',
      source: j['source'] as String? ?? 'direct',
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class SaleLineItem {
  final String productId;
  final String name;
  final int quantity;
  final int unitPriceKurus;

  const SaleLineItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPriceKurus,
  });

  factory SaleLineItem.fromJson(Map<String, dynamic> j) {
    return SaleLineItem(
      productId: j['productId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toInt() ?? 0,
      unitPriceKurus: (j['unitPriceKurus'] as num?)?.toInt() ?? 0,
    );
  }
}

String _methodLabel(String m) {
  switch (m) {
    case 'cash':
      return 'Nakit';
    case 'card':
      return 'Kart';
    case 'transfer':
      return 'Havale';
    default:
      return 'Diğer';
  }
}

/// Tek satış satırı.
class SaleCard extends StatelessWidget {
  const SaleCard({super.key, required this.sale});

  final SaleItem sale;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final s = sale;

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.customerName.isNotEmpty ? s.customerName : 'Genel satış',
                  style: HgText.bodyStrong.copyWith(color: c.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: HgSpace.sm),
              Text(
                formatCurrency(s.totalKurus),
                style: HgText.bodyStrong.copyWith(color: c.success),
              ),
            ],
          ),
          if (s.items.isNotEmpty) ...[
            const SizedBox(height: HgSpace.xs),
            Text(
              s.items.map((i) => '${i.name} ×${i.quantity}').join(', '),
              style: HgText.small.copyWith(color: c.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: HgSpace.sm),
          Row(
            children: [
              HgChip(label: _methodLabel(s.paymentMethod), color: c.blue),
              const SizedBox(width: HgSpace.sm),
              if (s.source == 'appointment')
                HgChip(label: 'Randevu', color: c.violet),
              const Spacer(),
              Text(
                formatDateTimeFromMs(s.createdAt),
                style: HgText.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
