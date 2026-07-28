// Hanagram — profil aksiyon butonları (fonksiyonel)
//
// Tek tıkla: Mesaj, Ara (url_launcher), Yol Tarifi (Google Maps), Randevu.
// Telefon ve yol tarifi gerçekten çalışır.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:hanagram_design/design.dart';

class ProfileActions extends StatelessWidget {
  const ProfileActions({
    super.key,
    required this.onAction,
    this.phone = '',
    this.address = '',
    this.latitude,
    this.longitude,
  });

  final ValueChanged<String> onAction;
  final String phone;
  final String address;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionBtn(
          icon: CupertinoIcons.chat_bubble,
          label: 'Mesaj',
          onTap: () => onAction('message'),
          c: c,
        ),
        _ActionBtn(
          icon: CupertinoIcons.phone,
          label: 'Ara',
          onTap: () => _makePhoneCall(context),
          c: c,
        ),
        _ActionBtn(
          icon: CupertinoIcons.location,
          label: 'Yol Tarifi',
          onTap: () => _openGoogleMaps(context),
          c: c,
        ),
        _ActionBtn(
          icon: CupertinoIcons.calendar,
          label: 'Randevu',
          onTap: () => onAction('appointment'),
          c: c,
        ),
      ],
    );
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    if (phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telefon numarası eklenmemiş')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arama başlatılamadı')),
        );
      }
    }
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    Uri uri;

    // Koordinatlar varsa doğrudan haritada aç
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    } else if (address.isNotEmpty) {
      // Adres varsa arama yap
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
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.c,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: c.violet.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: c.violet.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 20, color: c.violet),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: c.textMuted,
              )),
        ],
      ),
    );
  }
}
