// Hanagram — kayıt/giriş kapısı (orchestrator)
//
// 3 adımlı kayıt (Kod → İletişim → Kimlik) veya giriş modu.
// Form bileşenleri: login_form.dart, register_form.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup hide AuthChangeEvent;

import '../../core/app_state.dart';
import '../../core/referral_service.dart';
import '../../core/supabase_service.dart';
import 'package:hanagram_design/design.dart';
import 'login_form.dart';
import 'register_form.dart';
import 'widgets/invite_widgets.dart';

class InviteGate extends StatefulWidget {
  const InviteGate({super.key});

  @override
  State<InviteGate> createState() => _InviteGateState();
}

class _InviteGateState extends State<InviteGate> {
  // ─── Controllers ───
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  // ─── Kod alanı dinleyicisi ───
  // RegisterForm StatelessWidget olduğu için text değişiminde rebuildtetmek lazım.
  void _onCodeChanged() {
    if (mounted && _step == RegisterStep.code && !_codeVerified) {
      setState(() {});
    }
  }

  // ─── Kayıt akışı state ───
  RegisterStep _step = RegisterStep.code;
  bool _isEmail = true;
  bool _busy = false;
  bool _codeVerified = false;
  String _validCode = '';
  String _invitedBy = '';
  String _error = '';
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _usernameAvailable = false;
  String _accountType = 'personal';
  String? _avatarUrl;

  // ─── Giriş akışı state ───
  bool _isLoginMode = false;
  final _loginIdentifierCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginBusy = false;
  String _loginError = '';
  bool _loginPasswordVisible = false;

  // ─── Rate limiting ───
  int _failedLoginAttempts = 0;
  DateTime? _loginLockoutUntil;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_onCodeChanged);
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _loginIdentifierCtrl.dispose();
    _loginPasswordCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  //  GİRİŞ AKIŞI
  // ═══════════════════════════════════════════

  bool get _isLoginLocked {
    if (_loginLockoutUntil == null) return false;
    return DateTime.now().isBefore(_loginLockoutUntil!);
  }

  Future<void> _login() async {
    if (_isLoginLocked) {
      final remaining = _loginLockoutUntil!.difference(DateTime.now());
      final minutes = (remaining.inSeconds / 60).ceil();
      setState(() => _loginError = 'Çok fazla deneme. $minutes dakika bekleyin.');
      return;
    }

    final identifier = _loginIdentifierCtrl.text.trim();
    final password = _loginPasswordCtrl.text;

    if (identifier.isEmpty) {
      setState(() => _loginError = 'Kullanıcı adı, e-posta veya telefon girin.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _loginError = 'Şifrenizi girin.');
      return;
    }
    if (password.length < 6) {
      setState(() => _loginError = 'Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() {
      _loginBusy = true;
      _loginError = '';
    });

    try {
      String? email;

      if (identifier.contains('@')) {
        email = identifier.toLowerCase().trim();
      } else if (identifier.startsWith('+') || _isNumeric(identifier)) {
        setState(() {
          _loginBusy = false;
          _loginError = 'Telefon ile giriş için e-posta adresinizi kullanın.';
        });
        return;
      } else {
        try {
          final userRow = await SupabaseService.client
              .from('users')
              .select('email')
              .eq('username', identifier.toLowerCase().trim())
              .maybeSingle();

          if (userRow == null || userRow['email'] == null) {
            setState(() {
              _loginBusy = false;
              _loginError = 'Kullanıcı bulunamadı.';
              _failedLoginAttempts++;
              _checkLoginLockout();
            });
            return;
          }
          email = userRow['email'] as String;
        } catch (_) {
          setState(() {
            _loginBusy = false;
            _loginError = 'Bağlantı hatası. Tekrar deneyin.';
          });
          return;
        }
      }

      final res = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session != null && res.user != null) {
        _failedLoginAttempts = 0;
        _loginLockoutUntil = null;

        final userRow = await SupabaseService.client
            .from('users')
            .select('id, username, full_name, account_type')
            .eq('auth_id', res.user!.id)
            .maybeSingle();

        if (mounted) {
          if (userRow != null) {
            AppScope.of(context).updateSession(Session(
              userId: res.user!.id,
              name: userRow['full_name'] as String? ?? '',
              handle: userRow['username'] as String? ?? '',
              accountType: userRow['account_type'] as String? ?? 'personal',
              memberNumber: 0,
            ));
          } else {
            setState(() {
              _loginBusy = false;
              _loginError = 'Profil bulunamadı. Kayıt olmayı deneyin.';
            });
            await SupabaseService.client.auth.signOut();
            SupabaseService.clearCache();
          }
        }
      } else {
        setState(() {
          _loginBusy = false;
          _loginError = 'Giriş başarısız. Bilgilerinizi kontrol edin.';
          _failedLoginAttempts++;
          _checkLoginLockout();
        });
      }
    } on sup.AuthException catch (e) {
      _failedLoginAttempts++;
      _checkLoginLockout();
      setState(() {
        _loginBusy = false;
        _loginError = _mapAuthError(e.message);
      });
    } catch (_) {
      setState(() {
        _loginBusy = false;
        _loginError = 'Bir hata oluştu. Tekrar deneyin.';
      });
    }
  }

  void _checkLoginLockout() {
    if (_failedLoginAttempts >= 5) {
      _loginLockoutUntil = DateTime.now().add(const Duration(minutes: 15));
    }
  }

  String _mapAuthError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('invalid')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (lower.contains('email not confirmed')) {
      return 'E-posta adresiniz henüz doğrulanmamış.';
    }
    if (lower.contains('too many')) {
      return 'Çok fazla deneme. Birkaç dakika bekleyin.';
    }
    return 'Giriş başarısız. Tekrar deneyin.';
  }

  bool _isNumeric(String s) => double.tryParse(s) != null;

  // ═══════════════════════════════════════════
  //  KAYIT AKIŞI
  // ═══════════════════════════════════════════

  Future<void> _verifyCode() async {
    setState(() {
      _busy = true;
      _error = '';
    });

    final result = await ReferralService.verifyCode(_codeCtrl.text);

    setState(() {
      _busy = false;
      if (result.valid) {
        _validCode = result.code;
        _invitedBy = result.invitedBy;
        _codeVerified = true;
        _error = '';
      } else {
        _error = inviteErrorText(result.errorCode);
        _codeVerified = false;
      }
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      if (_isEmail) {
        final email = _emailCtrl.text.trim();
        if (email.isEmpty || !email.contains('@')) {
          setState(() {
            _busy = false;
            _error = 'Geçerli bir e-posta girin.';
          });
          return;
        }
        await SupabaseService.client.auth.signInWithOtp(email: email);
      } else {
        final phone = _phoneCtrl.text.trim();
        if (phone.isEmpty) {
          setState(() {
            _busy = false;
            _error = 'Telefon numarası girin.';
          });
          return;
        }
        await SupabaseService.client.auth.signInWithOtp(phone: phone);
      }

      setState(() {
        _busy = false;
        _otpSent = true;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Kod gönderilemedi. Tekrar deneyin.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      final otp = _otpCtrl.text.trim();
      if (otp.length != 6) {
        setState(() {
          _busy = false;
          _error = '6 haneli kodu girin.';
        });
        return;
      }

      final res = await SupabaseService.client.auth.verifyOTP(
        token: otp,
        type: _isEmail ? sup.OtpType.email : sup.OtpType.sms,
      );

      if (res.session != null) {
        setState(() {
          _busy = false;
          _otpVerified = true;
          _error = '';
        });
      } else {
        setState(() {
          _busy = false;
          _error = 'Kod hatalı.';
        });
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Doğrulama başarısız.';
      });
    }
  }

  Future<void> _createAccount() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Adını yazman gerekiyor.');
      return;
    }

    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      final authUser = SupabaseService.user;
      if (authUser == null) {
        setState(() {
          _busy = false;
          _error = 'Oturum bulunamadı. Baştan başlayın.';
          _step = RegisterStep.code;
        });
        return;
      }

      final username = _usernameCtrl.text.trim().toLowerCase();
      if (username.length < 3) {
        setState(() {
          _busy = false;
          _error = 'Kullanıcı adı en az 3 karakter olmalı.';
        });
        return;
      }

      final available = await ReferralService.isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _busy = false;
          _error = 'Bu kullanıcı adı alınmış.';
        });
        return;
      }

      final created = await ReferralService.createProfile(
        authId: authUser.id,
        username: username,
        fullName: name,
        accountType: _accountType,
        email: _isEmail ? _emailCtrl.text.trim() : null,
        // Telefon isteğe bağlı bir profil bilgisi — giriş yöntemiyle ilgisi yok.
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        referralCode: _validCode,
        avatarUrl: _avatarUrl,
      );

      if (created == null) {
        setState(() {
          _busy = false;
          _error = 'Hesap oluşturulamadı.';
        });
        return;
      }

      if (mounted) {
        AppScope.of(context).updateSession(Session(
          userId: authUser.id,
          name: name,
          handle: username,
          accountType: _accountType,
          memberNumber: 0,
        ));
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Bir hata oluştu. Tekrar deneyin.';
      });
    }
  }

  // ═══════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          const InviteBackdrop(),
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
                      Center(child: BrandMark(size: 76, animate: true)),
                      const SizedBox(height: HgSpace.lg),
                      const Center(child: BrandWordmark(fontSize: 30)),
                      const SizedBox(height: HgSpace.sm),

                      // Adım göstergesi (sadece kayıt modunda)
                      if (!_isLoginMode) ...[
                        _StepIndicator(current: _step, c: c),
                        const SizedBox(height: HgSpace.xxl),
                      ] else
                        const SizedBox(height: HgSpace.xl),

                      // İçerik
                      if (_isLoginMode)
                        LoginForm(
                          identifierCtrl: _loginIdentifierCtrl,
                          passwordCtrl: _loginPasswordCtrl,
                          busy: _loginBusy,
                          error: _loginError,
                          passwordVisible: _loginPasswordVisible,
                          isLocked: _isLoginLocked,
                          onLogin: _login,
                          onTogglePasswordVisibility: () => setState(
                              () => _loginPasswordVisible = !_loginPasswordVisible),
                          onSwitchToRegister: () => setState(() {
                            _isLoginMode = false;
                            _error = '';
                            _loginError = '';
                          }),
                        )
                      else
                        RegisterForm(
                          step: _step,
                          codeCtrl: _codeCtrl,
                          emailCtrl: _emailCtrl,
                          phoneCtrl: _phoneCtrl,
                          otpCtrl: _otpCtrl,
                          usernameCtrl: _usernameCtrl,
                          nameCtrl: _nameCtrl,
                          isEmail: _isEmail,
                          busy: _busy,
                          error: _error,
                          codeVerified: _codeVerified,
                          validCode: _validCode,
                          invitedBy: _invitedBy,
                          otpSent: _otpSent,
                          otpVerified: _otpVerified,
                          usernameAvailable: _usernameAvailable,
                          accountType: _accountType,
                          avatarUrl: _avatarUrl,
                          onVerifyCode: _verifyCode,
                          onProceedToContact: () =>
                              setState(() => _step = RegisterStep.contact),
                          onSendOtp: _sendOtp,
                          onVerifyOtp: _verifyOtp,
                          onProceedToIdentity: () =>
                              setState(() => _step = RegisterStep.identity),
                          onCreateAccount: _createAccount,
                          onToggleEmailPhone: (v) => setState(() {
                            _isEmail = v;
                            _otpSent = false;
                            _otpVerified = false;
                            _otpCtrl.clear();
                            _error = '';
                          }),
                          onUsernameChanged: (ok) =>
                              setState(() => _usernameAvailable = ok),
                          onAccountTypeChanged: (v) =>
                              setState(() => _accountType = v),
                          onAvatarSelected: (url) =>
                              setState(() => _avatarUrl = url),
                          onSwitchToLogin: () => setState(() {
                            _isLoginMode = true;
                            _loginError = '';
                            _loginIdentifierCtrl.clear();
                            _loginPasswordCtrl.clear();
                          }),
                          onBackToCode: () => setState(() {
                            _step = RegisterStep.code;
                            _error = '';
                            _codeVerified = false;
                            _otpSent = false;
                            _otpVerified = false;
                            _otpCtrl.clear();
                          }),
                          onUpdateStep: (s) => setState(() => _step = s),
                          onUpdateError: (e) => setState(() => _error = e),
                          onResetOtp: () => setState(() {
                            _otpSent = false;
                            _otpVerified = false;
                            _otpCtrl.clear();
                          }),
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

// ─── Adım göstergesi ───

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.c});
  final RegisterStep current;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (label: 'Kod', icon: Icons.vpn_key_outlined),
      (label: 'İletişim', icon: Icons.mail_outline),
      (label: 'Kimlik', icon: Icons.person_outline),
    ];

    final currentIndex = current.index;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 24,
              height: 2,
              color: i <= currentIndex ? c.violet : c.border,
            ),
          _StepDot(
            label: steps[i].label,
            icon: steps[i].icon,
            active: i <= currentIndex,
            current: i == currentIndex,
            c: c,
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.icon,
    required this.active,
    required this.current,
    required this.c,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool current;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? c.violet : c.surfaceAlt,
            border: Border.all(
              color: active ? c.violet : c.border,
              width: current ? 2 : 1,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: active ? c.onBrand : c.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: HgText.caption.copyWith(
            color: active ? c.text : c.textFaint,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
