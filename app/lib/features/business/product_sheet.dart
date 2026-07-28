// Hanagram — ürün ekle/düzenle sheet
//
// customer_sheet.dart kalıbına göre. product.create veya product.update çağırır.
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import 'product_item.dart';
import 'core_error_helper.dart';
class ProductSheet extends StatefulWidget {
  const ProductSheet({
    super.key,
    required this.businessId,
    this.product,
  });

  final String businessId;
  final ProductItem? product;

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _categoryCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(
        text: p != null ? (p.priceKurus / 100).toStringAsFixed(2) : '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final app = AppScope.of(context);
      final p = widget.product;
      final priceKurus =
          (double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0) * 100;
      final priceInt = priceKurus.round();

      if (p == null) {
        app.core.call('product.create', {
          'businessId': widget.businessId,
          'name': _nameCtrl.text,
          'description': _descCtrl.text,
          'priceKurus': priceInt,
          'category': _categoryCtrl.text,
        });
      } else {
        app.core.call('product.update', {
          'businessId': widget.businessId,
          'productId': p.id,
          'name': _nameCtrl.text,
          'description': _descCtrl.text,
          'priceKurus': priceInt,
          'category': _categoryCtrl.text,
        });
      }

      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final isEdit = widget.product != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
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
              Text(
                isEdit ? 'Ürün düzenle' : 'Yeni ürün',
                style: HgText.title.copyWith(color: c.text),
              ),
              const SizedBox(height: HgSpace.lg),
              HgFormField(
                label: 'Ürün adı (zorunlu)',
                controller: _nameCtrl,
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Açıklama',
                controller: _descCtrl,
                maxLines: 2,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Fiyat (₺, zorunlu)',
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v?.trim().isEmpty == true) return 'Fiyat gerekli';
                  if (double.tryParse(v!.replaceAll(',', '.')) == null) {
                    return 'Geçerli bir fiyat girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Kategori',
                controller: _categoryCtrl,
                hint: 'İçecek, Yiyecek, Hizmet...',
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
