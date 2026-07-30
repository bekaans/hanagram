// Hanagram — CRM müşteri portföyü
//
// Sadece gösterir, karar vermez. Veri Supabase customers tablosundan gelir.
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/customer_service.dart';
import 'package:hanagram_design/design.dart';
import 'customer_item.dart';
import 'customer_sheet.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<CustomerItem> _customers = const [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
    });
    final result = await CustomerService.getCustomers(query: _query);
    _customers = result.map((e) => CustomerItem.fromJson(e)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  void _openAddSheet() {
    final app = AppScope.of(context);
    final bizId = app.session!.userId;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CustomerSheet(businessId: bizId),
    ).then((added) {
      if (added == true) _loadCustomers();
    });
  }

  void _openEditSheet(CustomerItem c) {
    final app = AppScope.of(context);
    final bizId = app.session!.userId;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CustomerSheet(businessId: bizId, customer: c),
    ).then((updated) {
      if (updated == true) _loadCustomers();
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
        title: Text('Müşteriler',
            style: HgText.title.copyWith(color: c.text, shadows: null)),
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
        hint: 'Müşteri ara...',
        prefixIcon: const Icon(Icons.search, size: 20),
        onChanged: (v) {
          _query = v;
          _loadCustomers();
        },
      ),
    );
  }

  Widget _buildContent(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_customers.isEmpty && _query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Sonuç yok',
        message: 'Arama kriterlerine uygun müşteri bulunamadı.',
      );
    }
    if (_customers.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: 'Müşteri yok',
        message: 'İlk müşteriyi eklemek için + butonuna dokunun.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadCustomers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            HgSpace.lg, HgSpace.xs, HgSpace.lg, 96),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final cu = _customers[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: HgSpace.sm),
            child: CustomerCard(
              customer: cu,
              onTap: () => _openEditSheet(cu),
              onEdit: () => _openEditSheet(cu),
            ),
          );
        },
      ),
    );
  }
}
