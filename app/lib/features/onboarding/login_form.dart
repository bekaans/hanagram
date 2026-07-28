// Hanagram — giriş formu bileşeni
//
// InviteGate tarafından çağrılır. Tüm state InviteGate'te kalır,
// bu dosya yalnızca UI + input handling sorumlusudur.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({
    super.key,
    required this.identifierCtrl,
    required this.passwordCtrl,
    required this.busy,
    required this.error,
    required this.passwordVisible,
    required this.isLocked,
    required this.onLogin,
    required this.onTogglePasswordVisibility,
    required this.onSwitchToRegister,
  });

  final TextEditingController identifierCtrl;
  final TextEditingController passwordCtrl;
  final bool busy;
  final String error;
  final bool passwordVisible;
  final bool isLocked;
  final VoidCallback onLogin;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onSwitchToRegister;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Giriş Yap',
          style: HgText.heading.copyWith(color: c.text),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HgSpace.xs),
        Text(
          'Kullanıcı adı, e-posta veya telefon numaran ile giriş yap.',
          style: HgText.small.copyWith(color: c.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HgSpace.xl),

        // Kullanıcı adı / e-posta / telefon
        TextField(
          controller: identifierCtrl,
          style: HgText.body.copyWith(color: c.text),
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            c,
            hintText: 'Kullanıcı adı, e-posta veya telefon',
            icon: Icons.person_outline,
          ),
        ),
        const SizedBox(height: HgSpace.md),

        // Şifre
        TextField(
          controller: passwordCtrl,
          obscureText: !passwordVisible,
          style: HgText.body.copyWith(color: c.text),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onLogin(),
          decoration: _inputDecoration(
            c,
            hintText: 'Şifre',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: c.textMuted,
                size: 20,
              ),
              onPressed: onTogglePasswordVisibility,
            ),
          ),
        ),

        // Hata mesajı
        if (error.isNotEmpty) ...[
          const SizedBox(height: HgSpace.md),
          _ErrorBox(c: c, message: error),
        ],

        // Kilitleme uyarısı
        if (isLocked) ...[
          const SizedBox(height: HgSpace.md),
          _LockoutBox(c: c),
        ],

        const SizedBox(height: HgSpace.xl),

        // Giriş butonu
        BrandButton(
          label: busy ? 'Giriş yapılıyor...' : 'Giriş Yap',
          icon: Icons.login,
          busy: busy,
          onPressed: busy || isLocked ? null : onLogin,
        ),

        const SizedBox(height: HgSpace.md),

        // Kayıt ol bağlantısı
        Center(
          child: TextButton(
            onPressed: onSwitchToRegister,
            child: RichText(
              text: TextSpan(
                style: HgText.body.copyWith(color: c.textMuted),
                children: [
                  const TextSpan(text: 'Hesabın yok mu? '),
                  TextSpan(
                    text: 'Kayıt Ol',
                    style: HgText.bodyStrong.copyWith(color: c.violet),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    HgColors c, {
    required String hintText,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: c.textMuted, size: 20),
      suffixIcon: suffix,
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
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.c, required this.message});
  final HgColors c;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(HgRadius.sm),
        border: Border.all(color: c.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: c.danger),
          const SizedBox(width: HgSpace.sm),
          Expanded(
            child: Text(message, style: HgText.small.copyWith(color: c.danger)),
          ),
        ],
      ),
    );
  }
}

class _LockoutBox extends StatelessWidget {
  const _LockoutBox({required this.c});
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(HgRadius.sm),
        border: Border.all(color: c.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: c.warning),
          const SizedBox(width: HgSpace.sm),
          Expanded(
            child: Text(
              'Çok fazla başarısız deneme. Hesabınız 15 dakikalığına kilitlendi.',
              style: HgText.small.copyWith(color: c.warning),
            ),
          ),
        ],
      ),
    );
  }
}
