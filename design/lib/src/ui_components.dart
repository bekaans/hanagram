// Hanagram — genel UI bileşenleri
//
// Marka bağımsız, her yerde kullanılabilen tekrar eden bileşenler.
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Yüzey kartı — uygulamadaki tüm kutuların temeli.
class HgCard extends StatelessWidget {
  const HgCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HgSpace.lg),
    this.onTap,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final body = Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(HgRadius.lg),
        border: Border.all(color: accent ?? c.border),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HgRadius.lg),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

/// Renkli baş harf rozeti — profil görseli yoksa kullanılır.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.size = 40,
    this.gradient = false,
    this.hasStory = false,
  });

  final String name;
  final double size;
  final bool gradient;
  final bool hasStory;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final hash = name.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final palette = [c.coral, c.violet, c.blue, c.success, c.warning];
    final color = palette[hash % palette.length];

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient ? c.brand : null,
        color: gradient ? null : color.withValues(alpha: 0.22),
        border: Border.all(color: gradient ? Colors.transparent : color.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: gradient ? c.onBrand : color,
        ),
      ),
    );

    if (!hasStory) return avatar;
    return Container(
      width: size + 8,
      height: size + 8,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: c.brand,
      ),
      child: avatar,
    );
  }
}

/// Küçük etiket — konu, durum, rozet.
class HgChip extends StatelessWidget {
  const HgChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final tint = color ?? c.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? tint : tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(HgRadius.pill),
        border: Border.all(color: tint.withValues(alpha: filled ? 0 : 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: filled ? c.onBrand : tint),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: HgText.caption.copyWith(color: filled ? c.onBrand : tint),
          ),
        ],
      ),
    );
  }
}

/// Boş durum — her listenin bir karşılığı olmalı.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(HgSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surfaceAlt,
                  border: Border.all(color: c.border),
                ),
                child: Icon(icon, size: 26, color: c.textFaint),
              ),
              const SizedBox(height: HgSpace.lg),
              Text(title, style: HgText.heading.copyWith(color: c.text)),
              const SizedBox(height: HgSpace.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: HgText.small.copyWith(color: c.textMuted),
              ),
              if (action != null) ...[
                const SizedBox(height: HgSpace.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Metin giriş alanı.
class HgTextField extends StatelessWidget {
  const HgTextField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.prefixIcon,
    this.keyboardType,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: HgText.body.copyWith(color: c.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: HgText.body.copyWith(color: c.textFaint),
        prefixIcon: prefixIcon,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.textFaint.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.violet),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

/// Form metin giriş alanı (label + validator desteği).
class HgFormField extends StatelessWidget {
  const HgFormField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.hint,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? hint;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: HgText.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: HgSpace.xs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: HgText.body.copyWith(color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: HgText.body.copyWith(color: c.textFaint),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.textFaint.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.violet),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Birincil buton.
class HgButton extends StatelessWidget {
  const HgButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final enabled = onPressed != null && !loading;
    final btnColor = color ?? c.violet;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(HgRadius.md),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: btnColor.withValues(alpha: 0.28),
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
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: HgText.bodyStrong.copyWith(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
