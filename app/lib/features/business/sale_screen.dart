// Hanagram — satış listesi ekranı
//
// İşletmenin satış geçmişini gösterir, yeni satış kaydetme sheet'ini açar.
// Veri Supabase crm_entries (type='sale') tablosundan gelir.
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/crm_service.dart';
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
    final result = await CrmService.getSales();
    _sales = result.map((e) => SaleItem.fromJson(e)).toList();
    if (mounted) setState(() => _isLoading = false);
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
