// Hanagram — profil başlık bileşeni (Supabase)
//
// Ortada büyük avatar + isim + doğrulama yıldızı (sarı/mavi).
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hanagram_design/design.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.handle,
    required this.bio,
    required this.isBusiness,
    this.isVerified = false,
    this.referralCode,
  });

  final String name;
  final String handle;
  final String bio;
  final bool isBusiness;
  final bool isVerified;
  final String? referralCode;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    // Yıldız rengi: işletme → sarı, kişisel → mavi
    final badgeColor =
        isBusiness ? const Color(0xFFFFC107) : c.blue;
    final badgeLabel =
        isBusiness ? 'Doğrulanmış İşletme' : 'Doğrulanmış Hesap';

    return Column(
      children: [
        // Avatar + yıldız rozeti
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Avatar(name: name, size: 100, gradient: true),
              if (isVerified)
                Positioned(
                  bottom: 0,
                  right: -4,
                  child: Tooltip(
                    message: badgeLabel,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: HgSpace.md),
        // İsim + rozet satırı
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: HgText.heading.copyWith(
                color: c.text,
                shadows: HgShadow.subtle,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: HgSpace.sm),
              Icon(Icons.star, size: 16, color: badgeColor),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // Handle
        Text(
          '@$handle',
          style:
              HgText.caption.copyWith(color: c.textMuted),
        ),
        // Referans kodu (isteğe bağlı) — dokununca panoya kopyalanır
        if (referralCode != null) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () => _copyReferralCode(context, referralCode!, c),
            child: Text(
              'Referans: $referralCode',
              style: HgText.caption.copyWith(
                color: c.textFaint,
                shadows: null,
                decoration: TextDecoration.underline,
                decorationColor: c.textFaint,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        // Bio
        if (bio.isNotEmpty) ...[
          const SizedBox(height: HgSpace.sm),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: HgText.small
                .copyWith(color: c.textMuted),
          ),
        ],
      ],
    );
  }

  void _copyReferralCode(BuildContext context, String code, HgColors c) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kod kopyalandı!',
          style: HgText.body.copyWith(color: c.onBrand),
        ),
        backgroundColor: c.violet,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HgRadius.sm),
        ),
      ),
    );
  }
}
