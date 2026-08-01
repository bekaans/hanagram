// Hanagram — gerçek veriyle hizmet listesi bileşeni
//
// Her hizmet tam genişlikte kendi satırında, altında medya önizlemeleri.

import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../../core/service_catalog.dart';
import '../service_media_screen.dart';

/// Tek bir hizmetin verisi ve medya bilgisi.
class _ServiceEntry {
  const _ServiceEntry({
    required this.service,
    required this.media,
    required this.totalMedia,
  });
  final BusinessService service;
  final List<Map<String, dynamic>> media;
  final int totalMedia;
}

/// Profil hizmet listesi — gerçek veri, tam genişlik satırlar.
class ProfileServicesList extends StatefulWidget {
  const ProfileServicesList({super.key, required this.businessId});
  final String businessId;

  @override
  State<ProfileServicesList> createState() => _ProfileServicesListState();
}

class _ProfileServicesListState extends State<ProfileServicesList> {
  bool _loading = true;
  List<_ServiceEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileServicesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) {
      setState(() {
        _loading = true;
        _entries = [];
      });
      _load();
    }
  }

  Future<void> _load() async {
    final services = await ServiceCatalog.getServices(widget.businessId);

    final entries = await Future.wait(services.map((s) async {
      final results = await Future.wait([
        ServiceCatalog.getServiceMedia(s.id, limit: 10),
        ServiceCatalog.getServiceMediaCount(s.id),
      ]);
      return _ServiceEntry(
        service: s,
        media: results[0] as List<Map<String, dynamic>>,
        totalMedia: results[1] as int,
      );
    }));

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _openMedia(BusinessService service) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceMediaScreen(service: service),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(HgSpace.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı
        Row(
          children: [
            Icon(Icons.category_outlined, size: 16, color: c.violet),
            const SizedBox(width: HgSpace.sm),
            Text(
              'Hizmetler',
              style: HgText.heading.copyWith(color: c.text, shadows: null),
            ),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        // Hizmet kartları — tam genişlik, alt alta
        for (int i = 0; i < _entries.length; i++) ...[
          _buildServiceCard(_entries[i], c),
          if (i < _entries.length - 1)
            const SizedBox(height: HgSpace.md),
        ],
      ],
    );
  }

  // ── Hizmet kartı ────────────────────────────────────────

  Widget _buildServiceCard(_ServiceEntry entry, HgColors c) {
    final s = entry.service;
    final hasMedia = entry.media.isNotEmpty || entry.totalMedia > 0;

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      onTap: () => _openMedia(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ad + fiyat
          Row(
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: HgText.bodyStrong.copyWith(
                    color: c.text,
                    shadows: null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: HgSpace.sm),
              Text(
                s.priceLabel,
                style: HgText.bodyStrong.copyWith(
                  color: c.violet,
                  shadows: null,
                ),
              ),
            ],
          ),
          // Açıklama
          if (s.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              s.description,
              style: HgText.caption.copyWith(
                color: c.textMuted,
                shadows: null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Süre + kategori
          const SizedBox(height: 4),
          _buildInfoRow(s, c),
          // Medya şeridi
          if (hasMedia) ...[
            const SizedBox(height: HgSpace.sm),
            _buildMediaStrip(entry, c),
          ],
        ],
      ),
    );
  }

  // ── Bilgi satırı ────────────────────────────────────────

  Widget _buildInfoRow(BusinessService s, HgColors c) {
    final buf = StringBuffer('${s.durationMinutes} dk');
    if (s.category.isNotEmpty) buf.write(' · ${s.category}');
    return Text(
      buf.toString(),
      style: HgText.caption.copyWith(color: c.textFaint, shadows: null),
    );
  }

  // ── Yatay medya şeridi ──────────────────────────────────

  Widget _buildMediaStrip(_ServiceEntry entry, HgColors c) {
    final extra = entry.totalMedia - entry.media.length;
    final itemCount = entry.media.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, i) {
          if (i < entry.media.length) {
            return _buildMediaThumb(entry.media[i], c);
          }
          // "+N" fazladan medya hücresi
          return GestureDetector(
            onTap: () => _openMedia(entry.service),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(HgRadius.sm),
              ),
              child: Center(
                child: Text(
                  '+$extra',
                  style: HgText.bodyStrong.copyWith(
                    color: c.violet,
                    shadows: null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tek medya küçük resmi ───────────────────────────────

  Widget _buildMediaThumb(Map<String, dynamic> media, HgColors c) {
    final path = media['file_path'] as String? ?? '';
    final type = media['type'] as String? ?? 'photo';
    final isNetwork = path.startsWith('http');

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(HgRadius.sm),
      child: SizedBox(
        width: 64,
        height: 64,
        child: isNetwork
            ? Image.network(
                path,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(c),
              )
            : _placeholder(c),
      ),
    );

    if (type == 'video') {
      return Stack(
        children: [
          image,
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    return image;
  }

  Widget _placeholder(HgColors c) {
    return Container(
      width: 64,
      height: 64,
      color: c.surfaceAlt,
      child: Icon(Icons.image_outlined, size: 20, color: c.textFaint),
    );
  }
}