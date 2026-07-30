// Hanagram — müşteri yorumları bileşeni
//
// 5 yıldız, gerçek kullanıcı yorumu. Veri Supabase reviews tablosundan gelir.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../../core/review_service.dart';
import '../models/review_model.dart';

class ProfileReviews extends StatefulWidget {
  const ProfileReviews({
    super.key,
    required this.businessId,
    required this.canWrite,
    this.onWrote,
  });

  /// Yorumları görüntülenen işletmenin `users.id`'si.
  final String businessId;

  /// Bu profili görüntüleyen "Yorum Yap" butonunu görebilir mi (kendi
  /// profilinde değilse true).
  final bool canWrite;

  final VoidCallback? onWrote;

  @override
  State<ProfileReviews> createState() => _ProfileReviewsState();
}

class _ProfileReviewsState extends State<ProfileReviews> {
  List<Review> _reviews = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileReviews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await ReviewService.getReviews(businessId: widget.businessId);
    if (!mounted) return;
    setState(() {
      _reviews = result.map((e) => Review.fromJson(e)).toList();
      _isLoading = false;
    });
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  Future<void> _openWriteSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WriteReviewSheet(businessId: widget.businessId),
    );
    if (submitted == true) {
      _load();
      widget.onWrote?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final reviews = _reviews;
    final avg = _averageRating;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
        if (reviews.isEmpty)
          EmptyState(
            icon: CupertinoIcons.chat_bubble_text,
            title: 'Henüz yorum yok',
            message: widget.canWrite
                ? 'İlk yorumu sen bırak.'
                : 'Müşteriler değerlendirdikçe burada görünecek.',
          )
        else
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
                          child: Text('Doğrulanmış kullanıcı', style: TextStyle(
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
        // Yorum yap butonu — sadece başkasının profilinde
        if (widget.canWrite)
          GestureDetector(
            onTap: _openWriteSheet,
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

// ─── Yorum yazma sheet'i ───

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({required this.businessId});
  final String businessId;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final _textCtrl = TextEditingController();
  int _rating = 5;
  bool _isSaving = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final ok = await ReviewService.submitReview(
      businessId: widget.businessId,
      rating: _rating,
      comment: _textCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
      ),
      padding: EdgeInsets.fromLTRB(
        HgSpace.lg, HgSpace.lg, HgSpace.lg,
        MediaQuery.of(context).viewInsets.bottom + HgSpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: HgSpace.lg),
          Text('Yorum Ekle', style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.lg),

          // Yıldız seçimi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  size: 36,
                  color: c.warning,
                ),
              ),
            )),
          ),
          const SizedBox(height: HgSpace.lg),

          // Yorum
          HgFormField(label: 'Yorumunuz', controller: _textCtrl),
          const SizedBox(height: HgSpace.xl),

          // Kaydet
          SizedBox(
            width: double.infinity,
            child: BrandButton(
              label: 'Yayınla',
              busy: _isSaving,
              onPressed: _isSaving ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
