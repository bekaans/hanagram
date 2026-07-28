// Hanagram — yol tarifleri bileşeni (fonksiyonel)
//
// Adres + Google Maps entegrasyonu. Koordinatlar veya adres ile açılır.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hanagram_design/design.dart';

class ProfileDirections extends StatelessWidget {
  const ProfileDirections({
    super.key,
    this.address = '',
    this.latitude,
    this.longitude,
  });

  final String address;
  final double? latitude;
  final double? longitude;

  Future<void> _openMaps(BuildContext context) async {
    Uri uri;

    if (latitude != null && longitude != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    } else if (address.isNotEmpty && address != 'Adres eklenmemiş') {
      final encoded = Uri.encodeComponent(address);
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encoded');
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum bilgisi eklenmemiş')),
        );
      }
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Maps açılamadı')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final hasAddress =
        address.isNotEmpty && address != 'Adres eklenmemiş';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.location_solid,
                size: 16, color: c.violet),
            const SizedBox(width: HgSpace.sm),
            Text('Yol Tarifleri',
                style: HgText.heading
                    .copyWith(color: c.text, shadows: null)),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        Container(
          padding: const EdgeInsets.all(HgSpace.lg),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(HgRadius.md),
            border: Border.all(
                color: c.border.withValues(alpha: 0.5),
                width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasAddress ? address : 'Henüz adres eklenmemiş',
                style: HgText.body
                    .copyWith(color: c.text, shadows: null),
              ),
              if (latitude != null && longitude != null) ...[
                const SizedBox(height: HgSpace.sm),
                Text(
                    '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}',
                    style: HgText.caption
                        .copyWith(color: c.textMuted, shadows: null)),
              ],
              const SizedBox(height: HgSpace.md),
              // Harita placeholder
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      c.violet.withValues(alpha: 0.08),
                      c.blue.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(HgRadius.sm),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.map,
                          size: 36, color: c.textMuted),
                      if (!hasAddress) ...[
                        const SizedBox(height: HgSpace.sm),
                        Text('Ayarlaradan adres ekleyin',
                            style: HgText.caption
                                .copyWith(color: c.textFaint)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: HgSpace.md),
              GestureDetector(
                onTap: () => _openMaps(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [c.violet, c.blue]),
                    borderRadius:
                        BorderRadius.circular(HgRadius.sm),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.location,
                          size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Google Maps\'te Aç',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
