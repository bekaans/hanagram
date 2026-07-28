// Hanagram — Yorumlar ekranı (bağımsız, Supabase bağımlılığı yok)
//
// Müşteri yorumlarını listeler, yıldız puanı + yorum ekleme.
// Arkadram'ın yorumlar.tsx ekranının Flutter karşılığı.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../profile/models/review_model.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late List<Review> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = List.of(Review.sampleReviews);
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  void _openAddSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewAddSheet(
        onAdded: (review) {
          setState(() => _reviews.insert(0, review));
        },
      ),
    );
  }

  void _removeReview(int index) {
    setState(() => _reviews.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Yorumlar', style: HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: c.violet,
        child: Icon(Icons.rate_review_outlined, color: c.onBrand),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.lg, HgSpace.lg, 96),
          children: [
            // ─── Ortalama puan ───
            HgCard(
              child: Row(
                children: [
                  Text(
                    _averageRating.toStringAsFixed(1),
                    style: HgText.display.copyWith(color: c.text, shadows: null),
                  ),
                  const SizedBox(width: HgSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < _averageRating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 20,
                            color: c.warning,
                          )),
                        ),
                        const SizedBox(height: HgSpace.xs),
                        Text(
                          '${_reviews.length} değerlendirme',
                          style: HgText.caption.copyWith(color: c.textMuted, shadows: null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HgSpace.xl),

            // ─── Yorum listesi ───
            if (_reviews.isEmpty)
              EmptyState(
                icon: Icons.reviews_outlined,
                title: 'Henüz yorum yok',
                message: 'İlk yorumu + butonuyla ekleyin.',
              )
            else
              ..._reviews.asMap().entries.map((entry) {
                final idx = entry.key;
                final review = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: HgSpace.sm),
                  child: _ReviewCard(
                    review: review,
                    onDelete: () => _removeReview(idx),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ─── Yorum kartı ───

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onDelete});
  final Review review;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: c.violet.withValues(alpha: 0.15),
                child: Text(
                  review.avatarText.isNotEmpty ? review.avatarText : review.name[0],
                  style: HgText.bodyStrong.copyWith(color: c.violet, shadows: null),
                ),
              ),
              const SizedBox(width: HgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.name, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                        if (review.isVerified) ...[
                          const SizedBox(width: HgSpace.xs),
                          Icon(Icons.verified, size: 14, color: c.success),
                        ],
                      ],
                    ),
                    Text(review.date, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
                  ],
                ),
              ),
              // Yıldızlar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: c.warning,
                )),
              ),
              const SizedBox(width: HgSpace.sm),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline, size: 18, color: c.textFaint),
              ),
            ],
          ),
          const SizedBox(height: HgSpace.md),
          Text(review.text, style: HgText.body.copyWith(color: c.text, shadows: null)),
        ],
      ),
    );
  }
}

// ─── Yorum ekleme formu ───

class _ReviewAddSheet extends StatefulWidget {
  const _ReviewAddSheet({required this.onAdded});
  final ValueChanged<Review> onAdded;

  @override
  State<_ReviewAddSheet> createState() => _ReviewAddSheetState();
}

class _ReviewAddSheetState extends State<_ReviewAddSheet> {
  final _nameCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.isEmpty || _textCtrl.text.isEmpty) return;

    final initials = _nameCtrl.text.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    widget.onAdded(Review(
      name: _nameCtrl.text.trim(),
      rating: _rating,
      date: '${DateTime.now().day} ${_monthName(DateTime.now().month)} ${DateTime.now().year}',
      text: _textCtrl.text.trim(),
      isVerified: false,
      avatarText: initials,
    ));
    Navigator.pop(context, true);
  }

  String _monthName(int m) {
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return months[m - 1];
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

          // İsim
          HgFormField(label: 'İsim', controller: _nameCtrl),
          const SizedBox(height: HgSpace.md),

          // Yorum
          HgFormField(label: 'Yorumunuz', controller: _textCtrl),
          const SizedBox(height: HgSpace.xl),

          // Kaydet
          SizedBox(
            width: double.infinity,
            child: BrandButton(label: 'Yayınla', onPressed: _submit),
          ),
        ],
      ),
    );
  }
}
