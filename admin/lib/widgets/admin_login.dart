// Hanagram Admin — giriş ekranı (Supabase Auth)
//
// E-posta + şifre ile giriş. Supabase Auth kullanır.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.onLogin,
  });

  final Future<void> Function(String email, String password) onLogin;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'E-posta ve şifre gerekli');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogin(email, pass);
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials')) return 'E-posta veya şifre hatalı';
    if (s.contains('Email not confirmed')) return 'E-posta henüz doğrulanmamış';
    return 'Giriş başarısız: $s';
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 64),
              const SizedBox(height: HgSpace.lg),
              Text('Hanagram Yönetim',
                  style: HgText.title.copyWith(color: c.text)),
              const SizedBox(height: HgSpace.xs),
              Text('Yönetici girişi',
                  style: HgText.small.copyWith(color: c.textMuted)),
              const SizedBox(height: HgSpace.xl),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: HgText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  labelStyle: HgText.small.copyWith(color: c.textMuted),
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    borderSide: BorderSide(color: c.border),
                  ),
                ),
              ),
              const SizedBox(height: HgSpace.md),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: HgText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: HgText.small.copyWith(color: c.textMuted),
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    borderSide: BorderSide(color: c.border),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: HgSpace.md),
                Text(_error!, style: HgText.small.copyWith(color: c.danger)),
              ],
              const SizedBox(height: HgSpace.lg),
              SizedBox(
                width: double.infinity,
                child: BrandButton(
                  label: _busy ? 'Giriş yapılıyor…' : 'Panele gir',
                  icon: _busy ? null : Icons.lock_open,
                  onPressed: _busy ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
