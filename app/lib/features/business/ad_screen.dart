// Hanagram — reklam yönetimi ekranı
//
// İşletmenin reklam listesini gösterir, arama destekler, ekleme/düzenleme
// sheet'ini açar. Veri Supabase ads tablosundan gelir.
import 'package:flutter/material.dart';
import '../../core/ad_service.dart';
import 'package:hanagram_design/design.dart';
import 'ad_item.dart';
import 'ad_sheet.dart';

class AdScreen extends StatefulWidget {
  const AdScreen({super.key});

  @override
  State<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends State<AdScreen> {
  List<AdItem> _ads = const [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    final result = await AdService.getAds(query: _query);
    _ads = result.map((e) => AdItem.fromJson(e)).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  void _openAddSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AdSheet(),
    ).then((added) {
      if (added == true) _loadAds();
    });
  }

  void _openEditSheet(AdItem ad) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AdSheet(ad: ad),
    ).then((updated) {
      if (updated == true) _loadAds();
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
        title: Text('Reklamlar', style: HgText.title.copyWith(color: c.text)),
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
        hint: 'Reklam ara...',
        prefixIcon: const Icon(Icons.search, size: 20),
        onChanged: (v) {
          _query = v;
          _loadAds();
        },
      ),
    );
  }

  Widget _buildContent(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ads.isEmpty && _query.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'Sonuç yok',
        message: 'Arama kriterlerine uygun reklam bulunamadı.',
      );
    }
    if (_ads.isEmpty) {
      return EmptyState(
        icon: Icons.campaign_outlined,
        title: 'Reklam yok',
        message: 'İlk reklamı oluşturmak için + butonuna dokunun.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAds,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            HgSpace.lg, HgSpace.xs, HgSpace.lg, 96),
        itemCount: _ads.length,
        itemBuilder: (context, index) {
          final ad = _ads[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: HgSpace.sm),
            child: AdCard(
              ad: ad,
              onTap: () => _openEditSheet(ad),
              onEdit: () => _openEditSheet(ad),
            ),
          );
        },
      ),
    );
  }
}
