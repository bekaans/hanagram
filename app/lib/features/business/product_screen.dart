// Hanagram — ürün yönetimi ekranı
//
// İşletmenin ürün listesini gösterir, arama destekler, ekleme/düzenleme
// sheet'ini açar. Veri Supabase products tablosundan gelir.
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/product_service.dart';
import 'package:hanagram_design/design.dart';
import 'product_item.dart';
import 'product_sheet.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  List<ProductItem> _products = const [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    final result = await ProductService.getProducts(query: _query);
    _products = result.map((e) => ProductItem.fromJson(e)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  void _openAddSheet() {
    final app = AppScope.of(context);
    final bizId = app.session!.userId;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProductSheet(businessId: bizId),
    ).then((added) {
      if (added == true) _loadProducts();
    });
  }

  void _openEditSheet(ProductItem p) {
    final app = AppScope.of(context);
    final bizId = app.session!.userId;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProductSheet(businessId: bizId, product: p),
    ).then((updated) {
      if (updated == true) _loadProducts();
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
        title: Text('Ürünler', style: HgText.title.copyWith(color: c.text)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: c.violet,
        child: Icon(Icons.add, color: c.onBrand),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(c),
            const SizedBox(height: HgSpace.md),
            Expanded(child: _buildContent(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(HgColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg),
      child: HgTextField(
        hint: 'Ürün ara...',
        prefixIcon: const Icon(Icons.search, size: 20),
        onChanged: (v) {
          _query = v;
          _loadProducts();
        },
      ),
    );
  }

  Widget _buildContent(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty && _query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Sonuç yok',
        message: 'Arama kriterlerine uygun ürün bulunamadı.',
      );
    }
    if (_products.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Ürün yok',
        message: 'İlk ürünü eklemek için + butonuna dokunun.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            HgSpace.lg, HgSpace.xs, HgSpace.lg, 96),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final prod = _products[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: HgSpace.sm),
            child: ProductCard(
              product: prod,
              onTap: () => _openEditSheet(prod),
              onEdit: () => _openEditSheet(prod),
            ),
          );
        },
      ),
    );
  }
}
