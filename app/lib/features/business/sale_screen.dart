// Hanagram — satış listesi ekranı
//
// İşletmenin satış geçmişini gösterir, yeni satış kaydetme sheet'ini açar.
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import 'sale_item.dart';
import 'sale_sheet.dart';

class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  List<SaleItem> _sales = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final app = AppScope.of(context);
      final bizId = app.session!.userId;
      final result = app.core.call('sale.list', {
        'businessId': bizId,
      });
      final items = (result['items'] as List?) ?? const [];
      _sales = items
          .map((e) =>
              SaleItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on Exception catch (_) {
      // Core yoksa örnek satış verisi göster
      _sales = _sampleSales();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openNewSaleSheet() {
    final app = AppScope.of(context);
    final bizId = app.session!.userId;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SaleSheet(businessId: bizId),
    ).then((added) {
      if (added == true) _loadSales();
    });
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
        title: Text('Satışlar', style: HgText.title.copyWith(color: c.text)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewSaleSheet,
        backgroundColor: c.violet,
        child: Icon(Icons.add_shopping_cart, color: c.onBrand),
      ),
      body: SafeArea(
        bottom: false,
        child: _buildContent(c),
      ),
    );
  }

  Widget _buildContent(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sales.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Satış yok',
        message: 'İlk satışı kaydetmek için + butonuna dokunun.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSales,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            HgSpace.lg, HgSpace.xs, HgSpace.lg, 96),
        itemCount: _sales.length,
        itemBuilder: (context, index) {
          final sale = _sales[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: HgSpace.sm),
            child: SaleCard(sale: sale),
          );
        },
      ),
    );
  }
}

// ─── Örnek satış verisi (core yokken) ───

List<SaleItem> _sampleSales() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    SaleItem(
      id: 'ss1', businessId: 'demo',
      customerName: 'Elif Yılmaz',
      items: [SaleLineItem(productId: 'p1', name: 'Makyaj Kampanyası', quantity: 1, unitPriceKurus: 150000)],
      totalKurus: 150000, paymentMethod: 'cash',
      createdAt: now - 10800000,
    ),
    SaleItem(
      id: 'ss2', businessId: 'demo',
      customerName: 'Studio Nova',
      items: [SaleLineItem(productId: 'p2', name: 'Profesyonel Çekim', quantity: 1, unitPriceKurus: 320000)],
      totalKurus: 320000, paymentMethod: 'card',
      createdAt: now - 86400000,
    ),
    SaleItem(
      id: 'ss3', businessId: 'demo',
      customerName: 'Zeynep Arslan',
      items: [SaleLineItem(productId: 'p3', name: 'Kaş Laminasyonu', quantity: 2, unitPriceKurus: 80000)],
      totalKurus: 160000, paymentMethod: 'transfer',
      createdAt: now - 172800000,
    ),
    SaleItem(
      id: 'ss4', businessId: 'demo',
      customerName: 'Cenk Demir',
      items: [SaleLineItem(productId: 'p4', name: 'Saç Bakım Paketi', quantity: 1, unitPriceKurus: 250000)],
      totalKurus: 250000, paymentMethod: 'card',
      createdAt: now - 259200000,
    ),
  ];
}
