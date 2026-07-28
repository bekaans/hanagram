// Hanagram — referans kodu banner bileşeni
//
// Profilin üstünde kullanıcının benzersiz davet kodunu gösterir.
// Dokunma ile kopyala, paylaş ile gönder.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// share_plus paketi kaldırıldı — paylaşım SnackBar ile gösteriliyor

import 'package:hanagram_design/design.dart';

class ReferralCodeBanner extends StatelessWidget {
  const ReferralCodeBanner({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return GestureDetector(
      onTap: () => _copyToClipboard(context, c),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HgSpace.lg,
          vertical: HgSpace.md,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              c.violet.withValues(alpha: 0.08),
              c.blue.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(HgRadius.md),
          border: Border.all(
            color: c.violet.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // İkon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(HgRadius.sm),
              ),
              child: Icon(CupertinoIcons.gift, size: 18, color: c.violet),
            ),
            const SizedBox(width: HgSpace.md),
            // Metin
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Davet Kodun',
                    style: HgText.caption.copyWith(
                      color: c.textMuted,
                      shadows: null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: c.violet,
                    ),
                  ),
                ],
              ),
            ),
            // Kopyala ikonu
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: c.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(CupertinoIcons.doc_on_doc, size: 16, color: c.violet),
            ),
            const SizedBox(width: HgSpace.sm),
            // Paylaş ikonu
            GestureDetector(
              onTap: () => _shareCode(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: c.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(CupertinoIcons.square_arrow_up, size: 16, color: c.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, HgColors c) {
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

  void _shareCode(BuildContext context) {
    final text = 'Hanagram\'a katıl! Davet kodum: $code\nhttps://hanagram.app/invite/$code';
    Clipboard.setData(ClipboardData(text: text));
    final c = HgTheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Paylaşım metni kopyalandı!',
            style: HgText.body.copyWith(color: c.onBrand)),
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
