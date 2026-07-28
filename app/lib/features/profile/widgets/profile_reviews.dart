// Hanagram — müşteri yorumları bileşeni
//
// 5 yıldız, randevu sahipleri onaylı, Google tarzı.
import 'package:flutter/cupertino.dart';

import 'package:hanagram_design/design.dart';
import '../models/review_model.dart';

class ProfileReviews extends StatelessWidget {
  const ProfileReviews({super.key, required this.onAction});
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final reviews = Review.sampleReviews;
    final avg = Review.averageRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.star_fill, size: 16, color: c.warning),
            const SizedBox(width: HgSpace.sm),
            Text('Müşteri Yorumları', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        // Ortalama puan
        Container(
          padding: const EdgeInsets.all(HgSpace.lg),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(HgRadius.md),
            border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Row(
            children: [
              Text(avg.toStringAsFixed(1), style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w800, color: c.warning,
                fontFamily: '.SF Pro Text',
              )),
              const SizedBox(width: HgSpace.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Yıldızlar
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < avg.round()
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.star,
                      size: 16,
                      color: c.warning,
                    )),
                  ),
                  const SizedBox(height: 2),
                  Text('${reviews.length} yorum', style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: HgSpace.md),
        // Yorum listesi
        for (final review in reviews)
          Container(
            margin: const EdgeInsets.only(bottom: HgSpace.sm),
            padding: const EdgeInsets.all(HgSpace.md),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(HgRadius.sm),
              border: Border.all(color: c.border.withValues(alpha: 0.4), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Avatar(name: review.name, size: 32, gradient: true),
                    const SizedBox(width: HgSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review.name, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                          Row(
                            children: [
                              ...List.generate(5, (i) => Icon(
                                i < review.rating
                                    ? CupertinoIcons.star_fill
                                    : CupertinoIcons.star,
                                size: 11,
                                color: c.warning,
                              )),
                              const SizedBox(width: 4),
                              Text(review.date, style: HgText.caption.copyWith(color: c.textFaint, shadows: null)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (review.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Randevu sahibi', style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w600, color: c.success,
                        )),
                      ),
                  ],
                ),
                const SizedBox(height: HgSpace.sm),
                Text(review.text, style: HgText.caption.copyWith(color: c.text, shadows: null)),
              ],
            ),
          ),
        const SizedBox(height: HgSpace.md),
        // Yorum yap butonu
        GestureDetector(
          onTap: () => onAction('write_review'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(HgRadius.sm),
              border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.pencil, size: 14, color: c.textMuted),
                const SizedBox(width: 4),
                Text('Yorum Yap', style: HgText.bodyStrong.copyWith(color: c.textMuted, shadows: null)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
