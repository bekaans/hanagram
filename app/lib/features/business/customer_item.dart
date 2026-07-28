// Hanagram — CRM müşteri modeli ve kart görünümü.
//
// customer_screen.dart'dan ayrıldı (appointment_card.dart örneğine göre). Model ve
// kart aynı yerde durur çünkü ikisi de yalnızca birbirleri için var.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';

class CustomerItem {
  final String id;
  final String businessId;
  final String name;
  final String? phone;
  final String? email;
  final String? note;
  final List<String> tags;
  final String? linkedUserId;
  final int createdAt;
  final int lastVisitAt;
  final int visitCount;
  final int totalSpendKurus;

  const CustomerItem({
    required this.id,
    required this.businessId,
    required this.name,
    this.phone,
    this.email,
    this.note,
    this.tags = const [],
    this.linkedUserId,
    this.createdAt = 0,
    this.lastVisitAt = 0,
    this.visitCount = 0,
    this.totalSpendKurus = 0,
  });

  factory CustomerItem.fromJson(Map<String, dynamic> j) {
    List<String> tagList = const [];
    final tagsData = j['tags'];
    if (tagsData is List) {
      tagList = tagsData.map((e) => e as String).toList();
    }

    return CustomerItem(
      id: j['id'] as String? ?? '',
      businessId: j['businessId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      note: j['note'] as String?,
      tags: tagList,
      linkedUserId: j['linkedUserId'] as String?,
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      lastVisitAt: (j['lastVisitAt'] as num?)?.toInt() ?? 0,
      visitCount: (j['visitCount'] as num?)?.toInt() ?? 0,
      totalSpendKurus: (j['totalSpendKurus'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Tek müşteri satırı. `onTap` detay görüşmeye, `onEdit` düzenlemeye.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
    required this.onEdit,
  });

  final CustomerItem customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final cu = customer;

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
                  cu.name,
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
          if (cu.phone != null && cu.phone!.isNotEmpty) ...[
            const SizedBox(height: HgSpace.xs),
            Text(cu.phone!, style: HgText.small.copyWith(color: c.textMuted)),
          ],
          if (cu.tags.isNotEmpty) ...[
            const SizedBox(height: HgSpace.sm),
            Wrap(
              spacing: HgSpace.xs,
              children: cu.tags
                  .map((t) => HgChip(
                        label: t,
                        color: c.violet,
                        filled: false,
                      ))
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: HgSpace.xs),
          ],
          const SizedBox(height: HgSpace.sm),
          Row(
            children: [
              if (cu.visitCount > 0) ...[
                Icon(Icons.history, size: 14, color: c.textMuted),
                const SizedBox(width: HgSpace.xs),
                Text(
                  '${cu.visitCount} ziyaret',
                  style: HgText.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(width: HgSpace.lg),
                Text(
                  formatCurrency(cu.totalSpendKurus),
                  style: HgText.caption.copyWith(color: c.success),
                ),
              ] else ...[
                Text(
                  'Yeni müşteri',
                  style: HgText.caption.copyWith(color: c.textMuted),
                ),
              ],
              const Spacer(),
              if (cu.lastVisitAt > 0)
                Text(
                  'Son: ${formatDateFromMs(cu.lastVisitAt)}',
                  style: HgText.caption.copyWith(color: c.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
