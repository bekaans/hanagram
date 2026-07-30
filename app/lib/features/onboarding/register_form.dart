// Hanagram — kayıt formu bileşeni (3 adımlı: Kod → İletişim → Kimlik)
//
// InviteGate tarafından çağrılır. Tüm state InviteGate'te kalır,
// bu dosya yalnızca UI + input handling sorumlusudur.
import 'package:flutter/material.dart';

import '../../core/supabase_service.dart';
import 'package:hanagram_design/design.dart';
import 'widgets/invite_widgets.dart';
import 'widgets/registration_widgets.dart';

enum RegisterStep { code, contact, identity }

class RegisterForm extends StatelessWidget {
  const RegisterForm({
    super.key,
    required this.step,
    required this.codeCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.otpCtrl,
    required this.usernameCtrl,
    required this.nameCtrl,
    required this.isEmail,
    required this.busy,
    required this.error,
    required this.codeVerified,
    required this.validCode,
    required this.invitedBy,
    required this.otpSent,
    required this.otpVerified,
    required this.usernameAvailable,
    required this.accountType,
    required this.avatarUrl,
    required this.onVerifyCode,
    required this.onProceedToContact,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.onProceedToIdentity,
    required this.onCreateAccount,
    required this.onToggleEmailPhone,
    required this.onUsernameChanged,
    required this.onAccountTypeChanged,
    required this.onAvatarSelected,
    required this.onSwitchToLogin,
    required this.onBackToCode,
    required this.onUpdateStep,
    required this.onUpdateError,
    required this.onResetOtp,
  });

  final RegisterStep step;
  final TextEditingController codeCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController otpCtrl;
  final TextEditingController usernameCtrl;
  final TextEditingController nameCtrl;
  final bool isEmail;
  final bool busy;
  final String error;
  final bool codeVerified;
  final String validCode;
  final String invitedBy;
  final bool otpSent;
  final bool otpVerified;
  final bool usernameAvailable;
  final String accountType;
  final String? avatarUrl;

  final VoidCallback onVerifyCode;
  final VoidCallback onProceedToContact;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final VoidCallback onProceedToIdentity;
  final VoidCallback onCreateAccount;
  final ValueChanged<bool> onToggleEmailPhone;
  final ValueChanged<bool> onUsernameChanged;
  final ValueChanged<String> onAccountTypeChanged;
  final ValueChanged<String?> onAvatarSelected;
  final VoidCallback onSwitchToLogin;
  final VoidCallback onBackToCode;
  final ValueChanged<RegisterStep> onUpdateStep;
  final ValueChanged<String> onUpdateError;
  final VoidCallback onResetOtp;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return AnimatedSwitcher(
      duration: HgMotion.normal,
      switchInCurve: HgMotion.curve,
      child: switch (step) {
        RegisterStep.code => _codeStep(c),
        RegisterStep.contact => _contactStep(c),
        RegisterStep.identity => _identityStep(c),
      },
    );
  }

  // ─── Adım 1: Referans kodu ───

  Widget _codeStep(HgColors c) {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Davet kodun',
          style: HgText.heading.copyWith(color: c.text),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HgSpace.xs),
        Text(
          'Hanagram şu an davetle giriliyor. Kodu olan bir tanıdığından iste.',
          style: HgText.small.copyWith(color: c.textMuted),
          textAlign: TextAlign.center,
        ),

        // Doğrulanmış kod bilgisi
        if (codeVerified && invitedBy.isNotEmpty) ...[
          const SizedBox(height: HgSpace.lg),
          _VerifiedCodeBox(c: c, invitedBy: invitedBy, code: validCode),
        ],

        const SizedBox(height: HgSpace.xl),
        InviteCodeField(
          controller: codeCtrl,
          onSubmit: codeVerified ? onProceedToContact : onVerifyCode,
          error: error.isNotEmpty ? error : null,
          enabled: !codeVerified && !busy,
        ),

        if (error.isNotEmpty && !codeVerified) ...[
          const SizedBox(height: HgSpace.sm),
          _ErrorRow(c: c, message: error),
        ],

        const SizedBox(height: HgSpace.lg),
        BrandButton(
          label: busy
              ? 'Doğrulanıyor...'
              : codeVerified
                  ? 'Devam et'
                  : 'Kodu doğrula',
          icon: Icons.arrow_forward,
          busy: busy,
          onPressed: codeVerified
              ? onProceedToContact
              : (codeCtrl.text.trim().length >= 4 ? onVerifyCode : null),
        ),

        // Giriş yap bağlantısı
        const SizedBox(height: HgSpace.xl),
        Center(
          child: TextButton(
            onPressed: onSwitchToLogin,
            child: RichText(
              text: TextSpan(
                style: HgText.body.copyWith(color: c.textMuted),
                children: [
                  const TextSpan(text: 'Zaten hesabın var mı? '),
                  TextSpan(
                    text: 'Giriş Yap',
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

  // ─── Adım 2: İletişim bilgisi ───

  Widget _contactStep(HgColors c) {
    return Column(
      key: const ValueKey('contact'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VerifiedCodeBadge(c: c, code: validCode),
        const SizedBox(height: HgSpace.xl),

        Text(
          'İletişim bilgini gir',
          style: HgText.heading.copyWith(color: c.text),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HgSpace.sm),
        Text(
          'Hesabını doğrulamak için bir iletişim yolunu kullanacağız.',
          style: HgText.small.copyWith(color: c.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HgSpace.xl),

        // Telefon/SMS doğrulaması için Supabase'e henüz bir SMS sağlayıcısı
        // (Twilio vb.) bağlanmadı — şimdilik sadece e-posta ile kayıt.
        _EmailField(c: c, controller: emailCtrl),

        const SizedBox(height: HgSpace.lg),

        if (!otpSent)
          BrandButton(
            label: busy ? 'Gönderiliyor...' : 'Doğrulama kodu gönder',
            icon: Icons.send_outlined,
            busy: busy,
            onPressed: busy ? null : onSendOtp,
          ),

        if (otpSent) ...[
          OtpField(controller: otpCtrl, error: error.isNotEmpty ? error : null),
          const SizedBox(height: HgSpace.md),
          BrandButton(
            label: busy ? 'Doğrulanıyor...' : 'Kodu doğrula',
            icon: Icons.verified_outlined,
            busy: busy,
            onPressed: busy ? null : onVerifyOtp,
          ),
          const SizedBox(height: HgSpace.sm),
          Center(
            child: TextButton(
              onPressed: busy ? null : onSendOtp,
              child: Text('Kodu tekrar gönder',
                  style: HgText.small.copyWith(color: c.violet)),
            ),
          ),
        ],

        if (otpVerified) ...[
          const SizedBox(height: HgSpace.xl),
          UsernameField(
            controller: usernameCtrl,
            onChanged: onUsernameChanged,
          ),
          const SizedBox(height: HgSpace.xl),
          BrandButton(
            label: 'Devam et',
            icon: Icons.arrow_forward,
            onPressed: usernameAvailable ? onProceedToIdentity : null,
          ),
        ],

        const SizedBox(height: HgSpace.md),
        Center(
          child: TextButton(
            onPressed: onBackToCode,
            child: Text('Başka kod gir',
                style: HgText.small.copyWith(color: c.textMuted)),
          ),
        ),
      ],
    );
  }

  // ─── Adım 3: Kimlik ───

  Widget _identityStep(HgColors c) {
    return Column(
      key: const ValueKey('identity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Son adım',
          style: HgText.heading.copyWith(color: c.text),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HgSpace.xs),
        Text(
          'Hanagram deneyimini özelleştirelim.',
          style: HgText.small.copyWith(color: c.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: HgSpace.xl),

        Center(
          child: ProfilePhotoPicker(
            userId: SupabaseService.user?.id ?? '',
            onPhotoSelected: onAvatarSelected,
          ),
        ),
        const SizedBox(height: HgSpace.xl),

        Text('Hanagram\'ı nasıl kullanacaksın?',
            style: HgText.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: HgSpace.sm),
        AccountPicker(
          value: accountType,
          onChanged: onAccountTypeChanged,
        ),
        const SizedBox(height: HgSpace.xl),

        Text(
          accountType == 'business' ? 'İşletme adı' : 'Adın',
          style: HgText.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: HgSpace.sm),
        InviteTextField(
          controller: nameCtrl,
          hint: accountType == 'business' ? 'İşletme Adı' : 'Ad Soyad',
          onChanged: (_) {},
        ),
        const SizedBox(height: HgSpace.xl),

        Text('Telefon (isteğe bağlı)',
            style: HgText.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: HgSpace.sm),
        InviteTextField(
          controller: phoneCtrl,
          hint: '+90 5XX XXX XX XX',
          keyboardType: TextInputType.phone,
          onChanged: (_) {},
        ),
        const SizedBox(height: HgSpace.xl),

        if (error.isNotEmpty) ...[
          _ErrorRow(c: c, message: error),
          const SizedBox(height: HgSpace.md),
        ],

        BrandButton(
          label: busy ? 'Hesap oluşturuluyor...' : 'Hanagram\'a başla',
          icon: Icons.arrow_forward,
          busy: busy,
          onPressed: nameCtrl.text.trim().isEmpty || busy ? null : onCreateAccount,
        ),

        const SizedBox(height: HgSpace.sm),
        Text(
          'Hesap türünü sonradan profilinden değiştirebilirsin.',
          textAlign: TextAlign.center,
          style: HgText.caption.copyWith(color: c.textFaint),
        ),
      ],
    );
  }
}

// ─── Yardımcı widget'lar ───

class _VerifiedCodeBox extends StatelessWidget {
  const _VerifiedCodeBox({
    required this.c,
    required this.invitedBy,
    required this.code,
  });
  final HgColors c;
  final String invitedBy;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.success.withValues(alpha: 0.10),
            c.blue.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_outlined, size: 18, color: c.success),
          const SizedBox(width: HgSpace.sm),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: HgText.body.copyWith(color: c.text),
                children: [
                  const TextSpan(text: 'Referans veren: '),
                  TextSpan(
                    text: invitedBy,
                    style: HgText.bodyStrong.copyWith(color: c.success),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedCodeBadge extends StatelessWidget {
  const _VerifiedCodeBadge({required this.c, required this.code});
  final HgColors c;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HgSpace.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HgRadius.lg),
        gradient: LinearGradient(
          colors: [
            c.success.withValues(alpha: 0.12),
            c.blue.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: c.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: c.success),
          const SizedBox(width: HgSpace.sm),
          Text('Kod doğrulandı',
              style: HgText.bodyStrong.copyWith(color: c.text)),
          const Spacer(),
          Text(code, style: HgText.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.c, required this.message});
  final HgColors c;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 15, color: c.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message, style: HgText.small.copyWith(color: c.danger)),
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.c, required this.controller});
  final HgColors c;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      style: HgText.body.copyWith(color: c.text),
      decoration: _inputDecoration(c, 'ornek@email.com', Icons.email_outlined),
    );
  }
}

InputDecoration _inputDecoration(HgColors c, String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: c.textMuted, size: 20),
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
