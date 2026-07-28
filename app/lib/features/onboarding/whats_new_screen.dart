// Hanagram — "Yeni Sürüm Özeti" ekranı
//
// Her güncellemeden sonra bir kez gösterilir.
// Kullanıcı "Anladım" deyince kapanır ve bir daha gösterilmez.
// SharedPreferences'da son görülen versiyon saklanır.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/update_service.dart';
import 'package:hanagram_design/design.dart';

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key, required this.info, this.onDismiss});

  final UpdateInfo info;
  final VoidCallback? onDismiss;

  /// Bu versiyon daha önce gösterildi mi?
  static Future<bool> shouldShow(String currentVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString('last_seen_version') ?? '';
    return lastSeen != currentVersion;
  }

  /// Bu versiyonu görüldü olarak işaretle.
  static Future<void> markSeen(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_version', version);
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final lines = info.changelog.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          // Arka plan ışık lekeleri
          Positioned(
            top: -120,
            left: -80,
            child: _Glow(color: c.success, size: 300),
          ),
          Positioned(
            bottom: -140,
            right: -90,
            child: _Glow(color: c.blue, size: 350),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(HgSpace.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Başarı ikonu
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                c.success.withValues(alpha: 0.2),
                                c.blue.withValues(alpha: 0.2),
                              ],
                            ),
                            border: Border.all(
                              color: c.success.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            Icons.celebration,
                            size: 32,
                            color: c.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: HgSpace.xl),

                      // Başlık
                      Text(
                        'Güncellendi!',
                        style: HgText.title.copyWith(color: c.text),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: HgSpace.sm),

                      // Versiyon
                      Center(
                        child: HgChip(
                          label: 'v${info.version}',
                          color: c.success,
                        ),
                      ),
                      const SizedBox(height: HgSpace.xl),

                      // Değişiklik listesi
                      if (lines.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(HgSpace.lg),
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(HgRadius.md),
                            border: Border.all(color: c.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Neler yenilendi',
                                style: HgText.bodyStrong.copyWith(color: c.text),
                              ),
                              const SizedBox(height: HgSpace.md),
                              for (final line in lines)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: HgSpace.sm),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Madde işareti
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: line.startsWith('+')
                                                ? c.success
                                                : line.startsWith('!')
                                                    ? c.warning
                                                    : c.blue,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: HgSpace.md),
                                      Expanded(
                                        child: Text(
                                          line.trim(),
                                          style: HgText.body.copyWith(color: c.textMuted),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: HgSpace.xl),
                      ],

                      // Anladım butonu
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            await markSeen(info.version);
                            onDismiss?.call();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.violet,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(HgRadius.md),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Anladım',
                            style: HgText.bodyStrong.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
