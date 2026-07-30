// Hanagram — davet kapısı yardımcı widget'ları

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hanagram_design/design.dart';

/// Hata kodunu kullanıcıya özgü mesaja çevirir.
String inviteErrorText(String code) {
  switch (code) {
    case 'ERR_INVITE_INVALID':
      return 'Bu kod sistemde yok. Harfleri kontrol et.';
    case 'ERR_INVITE_EXPIRED':
      return 'Bu davetin süresi dolmuş. Davet edenden yenisini iste.';
    case 'ERR_INVITE_EXHAUSTED':
      return 'Bu kod daha önce kullanılmış.';
    case 'ERR_INVITE_REVOKED':
      return 'Bu davet iptal edilmiş.';
    case 'ERR_NAME_REQUIRED':
      return 'Adını yazman gerekiyor.';
    case 'ERR_ACCOUNT_TYPE_INVALID':
      return 'Bir hesap türü seç.';
    default:
      return 'Bir şeyler ters gitti ($code).';
  }
}

// ─── Davet kodu giriş alanı ───

class InviteCodeField extends StatelessWidget {
  const InviteCodeField({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.error,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      onSubmitted: (_) => onSubmit(),
      onChanged: (_) => (context as Element).markNeedsBuild(),
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      maxLength: 16,
      style: HgText.mono.copyWith(color: c.text, fontSize: 22),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\- ]')),
        TextInputFormatter.withFunction(
          (_, next) => next.copyWith(text: next.text.toUpperCase()),
        ),
      ],
      decoration: InputDecoration(
        hintText: '– – – – – – – –',
        counterText: '',
        hintStyle: HgText.mono.copyWith(color: c.textFaint, fontSize: 22),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgRadius.md),
          borderSide: BorderSide(color: error != null ? c.danger : c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgRadius.md),
          borderSide: BorderSide(color: c.violet, width: 1.6),
        ),
      ),
    );
  }
}

// ─── Genel metin giriş alanı ───

class InviteTextField extends StatelessWidget {
  const InviteTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
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
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: HgSpace.lg, vertical: HgSpace.lg),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgRadius.md),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgRadius.md),
          borderSide: BorderSide(color: c.violet, width: 1.6),
        ),
      ),
    );
  }
}

// ─── Hesap türü seçici ───

class AccountPicker extends StatelessWidget {
  const AccountPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('personal', 'Kişisel', 'Paylaş, keşfet, takip et', Icons.person_outline),
    ('creator', 'İçerik üreticisi', 'İçerik performansı ve araçlar', Icons.auto_awesome),
    ('business', 'İşletme', 'Randevu, müşteri, satış yönetimi', Icons.storefront_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      children: [
        for (final (key, title, desc, icon) in _options) ...[
          HgCard(
            onTap: () => onChanged(key),
            accent: value == key ? c.violet : null,
            padding: const EdgeInsets.all(HgSpace.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    gradient: value == key ? c.brand : null,
                    color: value == key ? null : c.surfaceAlt,
                  ),
                  child: Icon(icon,
                      size: 19, color: value == key ? c.onBrand : c.textMuted),
                ),
                const SizedBox(width: HgSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: HgText.bodyStrong.copyWith(color: c.text)),
                      Text(desc, style: HgText.caption.copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                Icon(
                  value == key ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: value == key ? c.violet : c.textFaint,
                ),
              ],
            ),
          ),
          const SizedBox(height: HgSpace.sm),
        ],
      ],
    );
  }
}

// ─── Arka plan ışık lekeleri ───

class InviteBackdrop extends StatelessWidget {
  const InviteBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -140,
              left: -90,
              child: _Glow(color: c.coral, size: 340),
            ),
            Positioned(
              bottom: -160,
              right: -110,
              child: _Glow(color: c.blue, size: 400),
            ),
            Positioned(
              top: 200,
              right: -60,
              child: _Glow(color: c.violet, size: 260),
            ),
          ],
        ),
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
          colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
