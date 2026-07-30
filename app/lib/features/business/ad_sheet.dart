// Hanagram — reklam ekle/düzenle sheet
//
// product_sheet.dart kalıbına göre. AdService.createAd/updateAd çağırır.
import 'package:flutter/material.dart';
import '../../core/ad_service.dart';
import 'package:hanagram_design/design.dart';
import 'ad_item.dart';

class AdSheet extends StatefulWidget {
  const AdSheet({
    super.key,
    this.ad,
  });

  final AdItem? ad;

  @override
  State<AdSheet> createState() => _AdSheetState();
}

class _AdSheetState extends State<AdSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _bidCtrl;
  late final TextEditingController _topicsCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ad = widget.ad;
    _titleCtrl = TextEditingController(text: ad?.title ?? '');
    _descCtrl = TextEditingController(text: ad?.description ?? '');
    _budgetCtrl = TextEditingController(
        text: ad != null ? (ad.dailyBudgetKurus / 100).toStringAsFixed(2) : '');
    _bidCtrl = TextEditingController(
        text: ad != null ? ad.bid.toStringAsFixed(1) : '1.0');
    _topicsCtrl = TextEditingController(
        text: ad?.targetTopics.join(', ') ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _bidCtrl.dispose();
    _topicsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final ad = widget.ad;
    final budgetKurus =
        (double.tryParse(_budgetCtrl.text.replaceAll(',', '.')) ?? 0) * 100;
    final bidVal = double.tryParse(_bidCtrl.text.replaceAll(',', '.')) ?? 1.0;
    final topics = _topicsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final ok = ad == null
        ? await AdService.createAd(
            title: _titleCtrl.text,
            description: _descCtrl.text,
            dailyBudgetKurus: budgetKurus.round(),
            bid: bidVal,
            targetTopics: topics,
          )
        : await AdService.updateAd(
            adId: ad.id,
            title: _titleCtrl.text,
            description: _descCtrl.text,
            dailyBudgetKurus: budgetKurus.round(),
            bid: bidVal,
            targetTopics: topics,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
      );
    }
  }

  Future<void> _togglePause() async {
    final ad = widget.ad;
    if (ad == null) return;
    final newStatus = ad.status == 'active' ? 'paused' : 'active';
    final ok = await AdService.updateAd(adId: ad.id, status: newStatus);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncellenemedi, tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final isEdit = widget.ad != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(HgSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Reklam düzenle' : 'Yeni reklam',
                      style: HgText.title.copyWith(color: c.text),
                    ),
                  ),
                  if (isEdit)
                    TextButton.icon(
                      onPressed: _togglePause,
                      icon: Icon(
                        widget.ad!.status == 'active'
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        size: 18,
                        color: widget.ad!.status == 'active'
                            ? c.warning
                            : c.success,
                      ),
                      label: Text(
                        widget.ad!.status == 'active' ? 'Duraklat' : 'Aktifleştir',
                        style: HgText.caption.copyWith(
                          color: widget.ad!.status == 'active'
                              ? c.warning
                              : c.success,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: HgSpace.lg),
              HgFormField(
                label: 'Başlık (zorunlu)',
                controller: _titleCtrl,
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Başlık gerekli' : null,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Açıklama',
                controller: _descCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: HgSpace.md),
              Row(
                children: [
                  Expanded(
                    child: HgFormField(
                      label: 'Günlük bütçe (₺)',
                      controller: _budgetCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Bütçe gerekli';
                        final val =
                            double.tryParse(v!.replaceAll(',', '.'));
                        if (val == null || val <= 0) return 'Geçerli bütçe girin';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: HgSpace.md),
                  Expanded(
                    child: HgFormField(
                      label: 'TBM (₺)',
                      controller: _bidCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      hint: '1.0',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Hedef konular (virgülle ayırın)',
                controller: _topicsCtrl,
                hint: 'kahve, yiyecek, spor',
              ),
              const SizedBox(height: HgSpace.xl),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: HgButton(
                    label: isEdit ? 'Güncelle' : 'Oluştur',
                    color: c.violet,
                    loading: _isSaving,
                    onPressed: _save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

