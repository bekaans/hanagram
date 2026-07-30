// Hanagram Admin — doğrulama istekleri sekmesi
//
// Kişisel/işletme doğrulama isteklerini listeler, onay/red işlemi yapılır.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class VerificationsTab extends StatefulWidget {
  const VerificationsTab({
    super.key,
    required this.requests,
    required this.onReview,
  });

  final List<Map<String, dynamic>> requests;
  final Future<void> Function(String requestId, bool approve) onReview;

  @override
  State<VerificationsTab> createState() => _VerificationsTabState();
}

class _VerificationsTabState extends State<VerificationsTab> {
  String _filter = 'pending';
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final filtered = widget.requests
        .where((r) => _filter == 'all' || r['status'] == _filter)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(HgSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Doğrulama İstekleri',
                  style: HgText.display.copyWith(color: c.text)),
              const SizedBox(width: HgSpace.md),
              HgChip(
                label: '${widget.requests.where((r) => r['status'] == 'pending').length} bekliyor',
                color: c.warning,
              ),
            ],
          ),
          const SizedBox(height: HgSpace.lg),
          Row(
            children: [
              _filterChip(c, 'pending', 'Bekleyen'),
              const SizedBox(width: HgSpace.sm),
              _filterChip(c, 'approved', 'Onaylı'),
              const SizedBox(width: HgSpace.sm),
              _filterChip(c, 'rejected', 'Reddedilen'),
              const SizedBox(width: HgSpace.sm),
              _filterChip(c, 'all', 'Tümü'),
            ],
          ),
          const SizedBox(height: HgSpace.lg),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.verified_outlined,
                    title: 'İstek yok',
                    message: 'Bu filtrede doğrulama isteği bulunmuyor.',
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: HgSpace.sm),
                    itemBuilder: (_, i) => _requestCard(c, filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(HgColors c, String value, String label) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.violet : c.surfaceAlt,
          borderRadius: BorderRadius.circular(HgRadius.pill),
        ),
        child: Text(label,
            style: HgText.small
                .copyWith(color: selected ? c.onBrand : c.textMuted)),
      ),
    );
  }

  Widget _requestCard(HgColors c, Map<String, dynamic> req) {
    final user = (req['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final type = req['request_type'] as String? ?? 'personal';
    final status = req['status'] as String? ?? 'pending';
    final id = req['id'] as String;
    final isBusy = _busyId == id;

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: user['full_name'] as String? ?? '?', size: 36),
              const SizedBox(width: HgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['full_name'] as String? ?? '?',
                        style: HgText.bodyStrong.copyWith(color: c.text)),
                    Text('@${user['username'] ?? '?'}',
                        style: HgText.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              HgChip(
                label: type == 'business' ? 'İşletme' : 'Kişisel',
                color: type == 'business' ? c.blue : c.violet,
              ),
              const SizedBox(width: HgSpace.sm),
              HgChip(
                label: switch (status) {
                  'approved' => 'Onaylı',
                  'rejected' => 'Red',
                  _ => 'Bekliyor',
                },
                color: switch (status) {
                  'approved' => c.success,
                  'rejected' => c.danger,
                  _ => c.warning,
                },
              ),
            ],
          ),
          const SizedBox(height: HgSpace.md),
          if (type == 'business') ...[
            _kv(c, 'İşletme adı', req['business_name'] as String? ?? ''),
            _kv(c, 'Vergi no', req['tax_no'] as String? ?? ''),
            _kv(c, 'Adres', req['business_address'] as String? ?? ''),
          ] else ...[
            _kv(c, 'Ad soyad', req['full_name'] as String? ?? ''),
            _kv(c, 'TC no', _maskTc(req['tc_no'] as String? ?? '')),
          ],
          const SizedBox(height: HgSpace.sm),
          Row(
            children: [
              for (final url in [
                req['front_image_url'],
                req['back_image_url'],
                req['tax_certificate_url'],
              ])
                if (url is String && url.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: HgSpace.sm),
                    child: GestureDetector(
                      onTap: () => _showImage(context, url),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(HgRadius.sm),
                        child: Image.network(url,
                            width: 64, height: 64, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                                  width: 64,
                                  height: 64,
                                  color: c.surfaceAlt,
                                  child: Icon(Icons.broken_image_outlined,
                                      color: c.textFaint, size: 20),
                                )),
                      ),
                    ),
                  ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: HgSpace.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _review(id, false),
                    icon: Icon(Icons.close, size: 16, color: c.danger),
                    label: Text('Reddet',
                        style: HgText.small.copyWith(color: c.danger)),
                  ),
                ),
                const SizedBox(width: HgSpace.sm),
                Expanded(
                  child: BrandButton(
                    label: isBusy ? 'İşleniyor…' : 'Onayla',
                    busy: isBusy,
                    onPressed: isBusy ? null : () => _review(id, true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _review(String id, bool approve) async {
    setState(() => _busyId = id);
    await widget.onReview(id, approve);
    if (mounted) setState(() => _busyId = null);
  }

  void _showImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _maskTc(String tc) {
    if (tc.length < 4) return tc;
    return '${tc.substring(0, 3)}${'*' * (tc.length - 5)}${tc.substring(tc.length - 2)}';
  }

  Widget _kv(HgColors c, String k, String v) {
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text('$k: ', style: HgText.caption.copyWith(color: c.textMuted)),
          Expanded(
            child: Text(v, style: HgText.caption.copyWith(color: c.text)),
          ),
        ],
      ),
    );
  }
}
