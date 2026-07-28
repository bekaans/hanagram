// Hanagram — marka bileşenleri
//
// Logo halkası kodla çizilir: her boyutta net kalır, uygulama paketine görsel
// eklemez ve tema ile birlikte davranır.
//
// Genel UI bileşenleri (HgCard, Avatar, HgChip vb.) → ui_components.dart
export 'ui_components.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Logodaki iç içe geçmiş halka. Marka gradyanını taşır.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.animate = false});

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: animate
          ? _Spin(child: CustomPaint(painter: _RingPainter(c)))
          : CustomPaint(painter: _RingPainter(c)),
    );
  }
}

class _Spin extends StatefulWidget {
  const _Spin({required this.child});
  final Widget child;
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations;
    if (!reduce) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _c, child: widget.child);
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.c);
  final HgColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    final gradient = SweepGradient(
      colors: [c.coral, c.violet, c.blue, c.coral],
      stops: const [0.0, 0.38, 0.72, 1.0],
      transform: const GradientRotation(-math.pi / 2),
    );

    for (var i = 0; i < 3; i++) {
      final t = i / 3;
      final r = size.width / 2 * (1 - t * 0.34) - size.width * 0.06;
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (0.11 - t * 0.02)
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center.translate(size.width * t * 0.05, 0), radius: r),
        -math.pi / 2 + t * 0.5,
        math.pi * 2 * (0.92 - t * 0.06),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.c != c;
}

/// Marka gradyanıyla yazılmış kelime işareti.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 26});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return ShaderMask(
      shaderCallback: (r) => c.brand.createShader(r),
      child: Text(
        'Hanagram',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w300,
          letterSpacing: fontSize * 0.06,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Birincil eylem düğmesi — marka gradyanı taşır.
class BrandButton extends StatelessWidget {
  const BrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final enabled = onPressed != null && !busy;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: c.brand,
          borderRadius: BorderRadius.circular(HgRadius.md),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: c.violet.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(HgRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(HgRadius.md),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: HgSpace.xl, vertical: HgSpace.lg),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.onBrand,
                      ),
                    )
                  else ...[
                    Text(
                      label,
                      style: HgText.bodyStrong.copyWith(color: c.onBrand),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: HgSpace.sm),
                      Icon(icon, size: 18, color: c.onBrand),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
