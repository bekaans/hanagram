// Hanagram — yeni satış kaydetme sheet
//
// İşletmenin ürün listesinden seçim yapıp satış kaydeder (Supabase crm_entries).
import 'package:flutter/material.dart';
import '../../core/crm_service.dart';
import '../../core/product_service.dart';
import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';
import 'product_item.dart';

class SaleSheet extends StatefulWidget {
  const SaleSheet({super.key, required this.businessId});

  final String businessId;

  @override
  State<SaleSheet> createState() => _SaleSheetState();
}

class _SaleSheetState extends State<SaleSheet> {
  List<ProductItem> _products = const [];
  final List<_LineItem> _lines = [];
  final _customerCtrl = TextEditingController();
  String _paymentMethod = 'cash';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final result = await ProductService.getProducts();
    _products = result.map((e) => ProductItem.fromJson(e)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  void _addLine(ProductItem product) {
    setState(() {
      final existing = _lines.where((l) => l.productId == product.id).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        _lines.add(_LineItem(
          productId: product.id,
          name: product.name,
          unitPriceKurus: product.priceKurus,
          quantity: 1,
        ));
      }
    });
  }

  void _removeLine(int index) {
    setState(() {
      if (_lines[index].quantity > 1) {
        _lines[index].quantity--;
      } else {
        _lines.removeAt(index);
      }
    });
  }

  int get _totalKurus =>
      _lines.fold(0, (sum, l) => sum + l.quantity * l.unitPriceKurus);

  Future<void> _save() async {
    if (_lines.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final items = _lines
          .map((l) => {
                'productId': l.productId,
                'name': l.name,
                'quantity': l.quantity,
                'unitPriceKurus': l.unitPriceKurus,
              })
          .toList();

      final saleId = await CrmService.createSale(
        items: items,
        customerName: _customerCtrl.text,
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;
      if (saleId != null) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satış kaydedilemedi, tekrar deneyin.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(HgSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yeni satış',
                      style: HgText.title.copyWith(color: c.text)),
                  const SizedBox(height: HgSpace.md),

                  // Müşteri adı
                  TextField(
                    controller: _customerCtrl,
                    style: HgText.body.copyWith(color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Müşteri adı (isteğe bağlı)',
                      hintStyle: HgText.body.copyWith(color: c.textFaint),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: HgSpace.md),

                  // Ödeme yöntemi
                  Row(
                    children: [
                      _PaymentChip(
                        label: 'Nakit',
                        value: 'cash',
                        selected: _paymentMethod == 'cash',
                        onTap: () =>
                            setState(() => _paymentMethod = 'cash'),
                      ),
                      const SizedBox(width: HgSpace.sm),
                      _PaymentChip(
                        label: 'Kart',
                        value: 'card',
                        selected: _paymentMethod == 'card',
                        onTap: () =>
                            setState(() => _paymentMethod = 'card'),
                      ),
                      const SizedBox(width: HgSpace.sm),
                      _PaymentChip(
                        label: 'Havale',
                        value: 'transfer',
                        selected: _paymentMethod == 'transfer',
                        onTap: () =>
                            setState(() => _paymentMethod = 'transfer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: HgSpace.md),

                  // Ürün seçimi
                  if (_products.isNotEmpty) ...[
                    Text('Ürün ekle',
                        style: HgText.caption.copyWith(color: c.textMuted)),
                    const SizedBox(height: HgSpace.xs),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _products.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: HgSpace.sm),
                        itemBuilder: (_, i) {
                          final p = _products[i];
                          return ActionChip(
                            label: Text(p.name,
                                style: HgText.small.copyWith(color: c.text)),
                            backgroundColor: c.surfaceAlt,
                            onPressed: () => _addLine(p),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Text('Henüz ürün yok. Önce ürün ekleyin.',
                        style: HgText.small.copyWith(color: c.textMuted)),
                  ],
                  const SizedBox(height: HgSpace.md),

                  // Seçili kalemler
                  if (_lines.isNotEmpty) ...[
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _lines.length,
                        itemBuilder: (_, i) {
                          final line = _lines[i];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: HgSpace.xs),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    line.name,
                                    style:
                                        HgText.body.copyWith(color: c.text),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline,
                                      size: 20, color: c.coral),
                                  onPressed: () => _removeLine(i),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: HgSpace.sm),
                                Text('${line.quantity}',
                                    style:
                                        HgText.body.copyWith(color: c.text)),
                                const SizedBox(width: HgSpace.sm),
                                Text(
                                  formatCurrency(
                                      line.quantity * line.unitPriceKurus),
                                  style: HgText.bodyStrong
                                      .copyWith(color: c.text),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Toplam',
                            style:
                                HgText.heading.copyWith(color: c.text)),
                        Text(
                          formatCurrency(_totalKurus),
                          style: HgText.heading
                              .copyWith(color: c.success),
                        ),
                      ],
                    ),
                  ] else ...[
                    Expanded(
                      child: Center(
                        child: Text(
                          'Ürün seçerek satış ekleyin',
                          style: HgText.small.copyWith(color: c.textMuted),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: HgSpace.md),
                  SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: HgButton(
                        label: 'Satışı kaydet',
                        color: c.violet,
                        loading: _isSaving,
                        onPressed: _lines.isEmpty ? null : _save,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LineItem {
  String productId;
  String name;
  int unitPriceKurus;
  int quantity;

  _LineItem({
    required this.productId,
    required this.name,
    required this.unitPriceKurus,
    this.quantity = 1,
  });
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.violet : c.surfaceAlt,
          borderRadius: BorderRadius.circular(HgRadius.pill),
          border: Border.all(
              color: selected ? c.violet : c.textFaint.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: HgText.small.copyWith(
            color: selected ? c.onBrand : c.textMuted,
          ),
        ),
      ),
    );
  }
}
