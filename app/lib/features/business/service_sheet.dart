// Hanagram — işletmenin hizmet ekleme/düzenleme alt sayfası (bottom sheet)
// Hizmet adı, açıklama, fiyat (₺/kuruş), süre ve kategori alanlarını düzenler.
// ServiceCatalog API'si üzerinden işletme ID'si içeriden çözülür.

import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/service_catalog.dart';

class ServiceSheet extends StatefulWidget {
  const ServiceSheet({super.key, this.service});
  final BusinessService? service;
  @override
  State<ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<ServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _categoryCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _priceCtrl = TextEditingController(
      text: s != null && s.price > 0 ? (s.price / 100).toStringAsFixed(2) : '',
    );
    _durationCtrl = TextEditingController(
      text: (s?.durationMinutes ?? 30).toString(),
    );
    _categoryCtrl = TextEditingController(text: s?.category ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  int get _parsedPriceKurus =>
      ((double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0) * 100).round();

  int get _parsedDuration => int.parse(_durationCtrl.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final s = widget.service;
      final bool ok;
      if (s == null) {
        final id = await ServiceCatalog.createService(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          price: _parsedPriceKurus,
          durationMinutes: _parsedDuration,
          category: _categoryCtrl.text.trim(),
        );
        ok = id != null;
      } else {
        ok = await ServiceCatalog.updateService(s.id, {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'price': _parsedPriceKurus,
          'duration_minutes': _parsedDuration,
          'category': _categoryCtrl.text.trim(),
        });
      }
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final isEdit = widget.service != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(HgSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Hizmeti düzenle' : 'Yeni hizmet',
                style: HgText.title.copyWith(color: c.text),
              ),
              const SizedBox(height: HgSpace.lg),
              HgFormField(
                label: 'Hizmet adı (zorunlu)',
                controller: _nameCtrl,
                validator: (v) => v?.trim().isEmpty == true ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Açıklama',
                controller: _descCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Fiyat (₺)',
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (n == null || n < 0) return 'Geçerli bir fiyat girin';
                  return null;
                },
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Süre (dakika, zorunlu)',
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                hint: '30',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Süre gerekli';
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Geçerli bir süre girin';
                  return null;
                },
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Kategori',
                controller: _categoryCtrl,
                hint: 'Lazer Epilasyon, Cilt Bakımı...',
              ),
              const SizedBox(height: HgSpace.xl),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: HgButton(
                    label: isEdit ? 'Güncelle' : 'Ekle',
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