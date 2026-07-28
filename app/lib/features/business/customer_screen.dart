// Hanagram — CRM müşteri portföyü
//
// Sadece gösterir, karar vermez. Tüm iş mantığı C++ çekirdekte.
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
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
    try {
      final app = AppScope.of(context);
      final bizId = app.session!.userId;
      final result = app.core.call('customer.list', {
        'businessId': bizId,
        'query': _query,
      });
      final items = (result['items'] as List?) ?? const [];
      _customers = items
          .map((e) =>
              CustomerItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on Exception catch (_) {
      // Core/Supabase yoksa örnek veri göster
      _customers = _sampleCustomers();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

// ─── Örnek müşteri verisi (core yokken) ───

List<CustomerItem> _sampleCustomers() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    CustomerItem(
      id: 'sc1', businessId: 'demo', name: 'Elif Yılmaz',
      phone: '0532 111 2233', note: 'Haftalık bakım paketi',
      tags: ['VIP', 'Düzenli'], createdAt: now - 86400000 * 30,
      lastVisitAt: now - 86400000 * 2, visitCount: 8, totalSpendKurus: 1500000,
    ),
    CustomerItem(
      id: 'sc2', businessId: 'demo', name: 'Dr. Ahmet Kaya',
      phone: '0535 444 5566', note: 'Instagram reklam kampanyası',
      tags: ['Reklam'], createdAt: now - 86400000 * 15,
      lastVisitAt: now - 86400000 * 5, visitCount: 3, totalSpendKurus: 3200000,
    ),
    CustomerItem(
      id: 'sc3', businessId: 'demo', name: 'Studio Nova',
      phone: '0216 333 4455', note: 'Profesyonel fotoğraf çekimi',
      tags: ['Çekim', 'Kurumsal'], createdAt: now - 86400000 * 60,
      lastVisitAt: now - 86400000 * 8, visitCount: 5, totalSpendKurus: 4500000,
    ),
    CustomerItem(
      id: 'sc4', businessId: 'demo', name: 'Zeynep Arslan',
      phone: '0542 777 8899', note: 'Kaş laminasyonu ve cilt bakımı',
      tags: ['Güzellik'], createdAt: now - 86400000 * 45,
      lastVisitAt: now - 86400000, visitCount: 12, totalSpendKurus: 980000,
    ),
    CustomerItem(
      id: 'sc5', businessId: 'demo', name: 'Cenk Demir',
      phone: '0538 222 3344', note: 'Saç bakım paketi',
      tags: [], createdAt: now - 86400000 * 10,
      lastVisitAt: now - 86400000 * 3, visitCount: 2, totalSpendKurus: 500000,
    ),
  ];
}
