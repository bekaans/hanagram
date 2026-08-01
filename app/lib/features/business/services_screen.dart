// Hanagram — işletme hizmet yönetimi ekranı
// Hizmetleri listeler, ekler, düzenler ve siler.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/service_catalog.dart';
import 'service_sheet.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<BusinessService> _services = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
    });
    final result = await ServiceCatalog.getMyServices();
    _services = result;
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _openSheet(BusinessService? service) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ServiceSheet(service: service),
    ).then((saved) {
      if (saved == true) _loadServices();
    });
  }

  Future<void> _confirmDelete(BusinessService service) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hizmeti sil'),
        content: Text(
          '"${service.name}" silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await ServiceCatalog.deleteService(service.id);
    if (!mounted) return;
    if (deleted) {
      _loadServices();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silinemedi, tekrar deneyin.')),
      );
    }
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
        title: Text('Hizmetler', style: HgText.title.copyWith(color: c.text)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSheet(null),
        backgroundColor: c.violet,
        child: Icon(Icons.add, color: c.onBrand),
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _services.isEmpty
                ? EmptyState(
                    icon: Icons.design_services_outlined,
                    title: 'Henüz hizmet eklemedin',
                    message:
                        'Sunduğun hizmetleri ekle — profilinde görünsün ve '
                        'müşterilerin randevu alabilsin.',
                  )
                : RefreshIndicator(
                    onRefresh: _loadServices,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _services.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) => _buildServiceCard(c, _services[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildServiceCard(HgColors c, BusinessService service) {
    return HgCard(
      onTap: () => _openSheet(service),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: HgText.bodyStrong.copyWith(color: c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (service.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    service.description,
                    style: HgText.caption.copyWith(color: c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      service.priceLabel,
                      style: HgText.caption.copyWith(color: c.violet),
                    ),
                    Text(
                      ' · ${service.durationMinutes} dk',
                      style: HgText.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
                if (service.category.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  HgChip(label: service.category),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.danger),
            onPressed: () => _confirmDelete(service),
          ),
        ],
      ),
    );
  }
}