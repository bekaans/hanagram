// Hanagram — içerik oluşturma sayfası
//
// Şu an için rafa kaldırıldı — basit "yakında" mesajı gösterir.
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.2,
      maxChildSize: 0.35,
      builder: (ctx, scrollCtrl) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF13101C).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tutamaç
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(
                      color: c.textFaint.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // İçerik
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: HgSpace.xl),
                    child: Column(
                      children: [
                        Icon(CupertinoIcons.hammer, size: 36, color: c.textMuted),
                        const SizedBox(height: HgSpace.md),
                        Text(
                          'Yakında',
                          style: HgText.heading.copyWith(color: c.text, shadows: null),
                        ),
                        const SizedBox(height: HgSpace.sm),
                        Text(
                          'İçerik oluşturma özellikleri şu an rafa kaldırıldı.\nÇok yakında geri dönecek!',
                          textAlign: TextAlign.center,
                          style: HgText.caption.copyWith(color: c.textMuted, shadows: null),
                        ),
                        const SizedBox(height: HgSpace.lg),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
