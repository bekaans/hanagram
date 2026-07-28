// Hanagram — reklam modeli ve kart görünümü.
//
// product_item.dart kalıbına göre.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';

class AdItem {
  final String id;
  final String businessId;
  final String title;
  final String description;
  final String imageUrl;
  final List<String> targetTopics;
  final int dailyBudgetKurus;
  final double bid;
  final String status;
  final int impressions;
  final int clicks;
  final int createdAt;
  final int updatedAt;

  const AdItem({
    required this.id,
    required this.businessId,
    required this.title,
    this.description = '',
    this.imageUrl = '',
    this.targetTopics = const [],
    this.dailyBudgetKurus = 0,
    this.bid = 1.0,
    this.status = 'active',
    this.impressions = 0,
    this.clicks = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory AdItem.fromJson(Map<String, dynamic> j) {
    return AdItem(
      id: j['id'] as String? ?? '',
      businessId: j['businessId'] as String? ?? '',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      imageUrl: j['imageUrl'] as String? ?? '',
      targetTopics: (j['targetTopics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      dailyBudgetKurus: (j['dailyBudgetKurus'] as num?)?.toInt() ?? 0,
      bid: (j['bid'] as num?)?.toDouble() ?? 1.0,
      status: j['status'] as String? ?? 'active',
      impressions: (j['impressions'] as num?)?.toInt() ?? 0,
      clicks: (j['clicks'] as num?)?.toInt() ?? 0,
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

Color _statusColor(String status, HgColors c) {
  switch (status) {
    case 'active':
      return c.success;
    case 'paused':
      return c.warning;
    case 'expired':
      return c.danger;
    default:
      return c.textFaint;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Aktif';
    case 'paused':
      return 'Duraklatılmış';
    case 'expired':
      return 'Süresi dolmuş';
    default:
      return 'Taslak';
  }
}

/// Tek reklam satırı.
class AdCard extends StatelessWidget {
  const AdCard({
    super.key,
    required this.ad,
    required this.onTap,
    required this.onEdit,
  });

  final AdItem ad;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

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
                  ad.title,
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
          if (ad.description.isNotEmpty) ...[
            const SizedBox(height: HgSpace.xs),
            Text(
              ad.description,
              style: HgText.small.copyWith(color: c.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (ad.targetTopics.isNotEmpty) ...[
            const SizedBox(height: HgSpace.xs),
            Wrap(
              spacing: HgSpace.xs,
              runSpacing: HgSpace.xs,
              children: ad.targetTopics
                  .take(3)
                  .map((t) => HgChip(label: t, color: c.blue, filled: false))
                  .toList(),
            ),
          ],
          const SizedBox(height: HgSpace.sm),
          Row(
            children: [
              HgChip(
                label: _statusLabel(ad.status),
                color: _statusColor(ad.status, c),
                filled: false,
              ),
              const Spacer(),
              Text(
                formatCurrency(ad.dailyBudgetKurus),
                style: HgText.caption.copyWith(color: c.textMuted),
              ),
              Text(
                ' /gün',
                style: HgText.caption.copyWith(color: c.textFaint),
              ),
            ],
          ),
          const SizedBox(height: HgSpace.xs),
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 14, color: c.textFaint),
              const SizedBox(width: 4),
              Text(
                '${ad.impressions}',
                style: HgText.caption.copyWith(color: c.textMuted),
              ),
              const SizedBox(width: HgSpace.md),
              Icon(Icons.touch_app_outlined, size: 14, color: c.textFaint),
              const SizedBox(width: 4),
              Text(
                '${ad.clicks}',
                style: HgText.caption.copyWith(color: c.textMuted),
              ),
              const Spacer(),
              Text(
                'TBM: ${ad.bid.toStringAsFixed(1)}₺',
                style: HgText.caption.copyWith(color: c.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
