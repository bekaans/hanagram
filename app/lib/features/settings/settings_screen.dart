// Hanagram — ayarlar ekranı (SOLID, responsive, liquid glass)
//
// Tek sorumluluk: kullanıcı tercihleri.
// Tüm widget'lar bağımsız, test edilebilir, responsive.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sup hide AuthChangeEvent;

import 'package:hanagram_design/design.dart';
import '../../core/app_state.dart';
import '../../core/supabase_service.dart';
import '../../core/verification_service.dart';
import 'settings_provider.dart';
import 'settings_widgets.dart';
import 'verification_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final s = SettingsScope.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Ayarlar',
            style: HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > HgBreak.tablet;
          final content = _SettingsContent(settings: s);
          if (isWide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: content,
              ),
            );
          }
          return content;
        },
      ),
    );
  }
}

// ─── Ana içerik ───

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.settings});
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.sm, HgSpace.lg, bottomPad + HgSpace.xxl),
      children: [
        _buildAccountSection(context, c, settings),
        const SizedBox(height: HgSpace.xl),
        _buildAppearanceSection(context, c, settings),
        const SizedBox(height: HgSpace.xl),
        _buildNotificationSection(context, c, settings),
        const SizedBox(height: HgSpace.xl),
        _buildPrivacySection(context, c, settings),
        const SizedBox(height: HgSpace.xl),
        _buildVerificationSection(context, c),
        const SizedBox(height: HgSpace.xl),
        _buildExperienceSection(context, c, settings),
        const SizedBox(height: HgSpace.xl),
        _buildAboutSection(context, c),
        const SizedBox(height: HgSpace.xl),
        _buildLogoutSection(context, c),
      ],
    );
  }

  // ─── Hesap Yönetimi Bölümü ───

  Widget _buildAccountSection(BuildContext context, HgColors c, SettingsProvider s) {
    final app = AppScope.of(context);
    final session = app.session;
    final email = SupabaseService.user?.email ?? '';

    return SettingsSection(
      icon: CupertinoIcons.person_circle,
      title: 'Hesap',
      children: [
        SettingsNavigationTile(
          icon: CupertinoIcons.person,
          label: 'Ad Soyad',
          value: session?.name ?? '',
          onTap: () => _showEditNameSheet(context, c, app),
        ),
        SettingsNavigationTile(
          icon: CupertinoIcons.envelope,
          label: 'E-posta',
          value: _maskedEmail(email),
          onTap: () => _showEditEmailSheet(context, c),
        ),
        SettingsNavigationTile(
          icon: CupertinoIcons.lock,
          label: 'Şifre',
          value: '••••••••',
          onTap: () => _showEditPasswordSheet(context, c),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context, HgColors c, SettingsProvider s) {
    return SettingsSection(
      icon: CupertinoIcons.paintbrush,
      title: 'Görünüm',
      children: [
        ThemePicker(settings: s),
      ],
    );
  }

  Widget _buildNotificationSection(BuildContext context, HgColors c, SettingsProvider s) {
    return SettingsSection(
      icon: CupertinoIcons.bell,
      title: 'Bildirimler',
      children: [
        SettingsToggleTile(
          label: 'Bildirimleri aç',
          value: s.notificationsEnabled,
          onChanged: s.toggleNotifications,
        ),
        if (s.notificationsEnabled) ...[
          SettingsToggleTile(
            label: 'Mesaj bildirimleri',
            value: s.messageNotifications,
            onChanged: s.toggleMessageNotifications,
          ),
          SettingsToggleTile(
            label: 'Randevu hatırlatmaları',
            value: s.appointmentReminders,
            onChanged: s.toggleAppointmentReminders,
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacySection(BuildContext context, HgColors c, SettingsProvider s) {
    return SettingsSection(
      icon: CupertinoIcons.shield,
      title: 'Gizlilik',
      children: [
        SettingsToggleTile(
          label: 'Çevrimiçi görünürlük',
          subtitle: 'Diğer kişiler çevrimiçi olduğunuzu görebilir',
          value: s.showOnlineStatus,
          onChanged: s.toggleOnlineStatus,
        ),
        SettingsToggleTile(
          label: 'Okundu bilgisi',
          subtitle: 'Mesajlarınızın okunduğunu gösterir',
          value: s.showReadReceipts,
          onChanged: s.toggleReadReceipts,
        ),
      ],
    );
  }

  Widget _buildVerificationSection(BuildContext context, HgColors c) {
    return _VerificationSection(c: c);
  }

  Widget _buildExperienceSection(BuildContext context, HgColors c, SettingsProvider s) {
    return SettingsSection(
      icon: CupertinoIcons.slider_horizontal_3,
      title: 'Deneyim',
      children: [
        SettingsToggleTile(
          label: 'Dokunsal geri bildirim',
          subtitle: 'Dokunmalarda titreme efekti',
          value: s.hapticFeedback,
          onChanged: s.toggleHapticFeedback,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, HgColors c) {
    return SettingsSection(
      icon: CupertinoIcons.info,
      title: 'Hakkında',
      children: [
        SettingsInfoTile(
          icon: CupertinoIcons.gear,
          label: 'Sürüm',
          value: '1.0.0',
        ),
        SettingsInfoTile(
          icon: CupertinoIcons.device_phone_portrait,
          label: 'Platform',
          value: _platformName(context),
        ),
      ],
    );
  }

  Widget _buildLogoutSection(BuildContext context, HgColors c) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _confirmLogout(context, c),
        icon: const Icon(CupertinoIcons.square_arrow_right, size: 18, color: Colors.red),
        label: const Text('Çıkış yap', style: TextStyle(color: Colors.red)),
      ),
    );
  }

  String _platformName(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Bilinmeyen';
    }
  }

  String _maskedEmail(String email) {
    if (email.isEmpty) return 'Tanımlanmamış';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return email;
    return '${name[0]}***@$domain';
  }

  // ─── Ad Soyad Düzenleme ───

  void _showEditNameSheet(BuildContext context, HgColors c, AppState app) {
    final ctrl = TextEditingController(text: app.session?.name ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          HgSpace.lg,
          HgSpace.lg,
          HgSpace.lg,
          MediaQuery.of(ctx).viewInsets.bottom + HgSpace.lg,
        ),
        child: Container(
          padding: const EdgeInsets.all(HgSpace.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(HgRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ad Soyad Değiştir',
                  style: HgText.heading.copyWith(color: c.text, shadows: null)),
              const SizedBox(height: HgSpace.lg),
              TextField(
                controller: ctrl,
                style: HgText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'Yeni adınızı girin',
                  hintStyle: HgText.body.copyWith(color: c.textFaint),
                  filled: true,
                  fillColor: c.surfaceAlt.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: HgSpace.lg),
              GestureDetector(
                onTap: () async {
                  final newName = ctrl.text.trim();
                  if (newName.isEmpty) return;
                  app.updateProfile(name: newName);
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ad güncellendi: $newName'),
                        backgroundColor: c.success,
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
                  decoration: BoxDecoration(
                    color: c.violet,
                    borderRadius: BorderRadius.circular(HgRadius.md),
                  ),
                  child: Center(
                    child: Text('Kaydet',
                        style: HgText.bodyStrong.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── E-posta Düzenleme ───

  void _showEditEmailSheet(BuildContext context, HgColors c) {
    final ctrl = TextEditingController(text: SupabaseService.user?.email ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          HgSpace.lg,
          HgSpace.lg,
          HgSpace.lg,
          MediaQuery.of(ctx).viewInsets.bottom + HgSpace.lg,
        ),
        child: Container(
          padding: const EdgeInsets.all(HgSpace.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(HgRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('E-posta Değiştir',
                  style: HgText.heading.copyWith(color: c.text, shadows: null)),
              const SizedBox(height: HgSpace.sm),
              Text('Yeni e-posta adresinize doğrulama bağlantısı gönderilecektir.',
                  style: HgText.small.copyWith(color: c.textMuted, shadows: null)),
              const SizedBox(height: HgSpace.lg),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                style: HgText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'ornek@email.com',
                  hintStyle: HgText.body.copyWith(color: c.textFaint),
                  filled: true,
                  fillColor: c.surfaceAlt.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: HgSpace.lg),
              GestureDetector(
                onTap: () async {
                  final newEmail = ctrl.text.trim();
                  if (newEmail.isEmpty || !newEmail.contains('@')) return;
                  try {
                    await SupabaseService.client.auth.updateUser(
                      sup.UserAttributes(email: newEmail),
                    );
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Doğrulama bağlantısı gönderildi: $newEmail'),
                          backgroundColor: c.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Hata: $e'),
                          backgroundColor: c.danger,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
                  decoration: BoxDecoration(
                    color: c.violet,
                    borderRadius: BorderRadius.circular(HgRadius.md),
                  ),
                  child: Center(
                    child: Text('Güncelle',
                        style: HgText.bodyStrong.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Şifre Değiştirme ───

  void _showEditPasswordSheet(BuildContext context, HgColors c) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          HgSpace.lg,
          HgSpace.lg,
          HgSpace.lg,
          MediaQuery.of(ctx).viewInsets.bottom + HgSpace.lg,
        ),
        child: Container(
          padding: const EdgeInsets.all(HgSpace.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(HgRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Şifre Değiştir',
                  style: HgText.heading.copyWith(color: c.text, shadows: null)),
              const SizedBox(height: HgSpace.sm),
              Text('En az 6 karakter olmalıdır.',
                  style: HgText.small.copyWith(color: c.textMuted, shadows: null)),
              const SizedBox(height: HgSpace.lg),
              TextField(
                controller: ctrl,
                obscureText: true,
                style: HgText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'Yeni şifre',
                  hintStyle: HgText.body.copyWith(color: c.textFaint),
                  filled: true,
                  fillColor: c.surfaceAlt.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HgRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: HgSpace.lg),
              GestureDetector(
                onTap: () async {
                  final newPass = ctrl.text.trim();
                  if (newPass.length < 6) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Text('Şifre en az 6 karakter olmalıdır'),
                          backgroundColor: c.danger,
                        ),
                      );
                    }
                    return;
                  }
                  try {
                    await SupabaseService.client.auth.updateUser(
                      sup.UserAttributes(password: newPass),
                    );
                    Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Şifre başarıyla güncellendi'),
                          backgroundColor: c.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Hata: $e'),
                          backgroundColor: c.danger,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
                  decoration: BoxDecoration(
                    color: c.violet,
                    borderRadius: BorderRadius.circular(HgRadius.md),
                  ),
                  child: Center(
                    child: Text('Güncelle',
                        style: HgText.bodyStrong.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, HgColors c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Çıkış yap', style: HgText.heading.copyWith(color: c.text, shadows: null)),
        content: Text(
          'Çıkış yapmak istediğinize emin misiniz?\n\nTüm yerel verileriniz silinecektir. Verileriniz bulutta korunur, tekrar giriş yaptığınızda her şey yerli yerinde olur.',
          style: HgText.body.copyWith(color: c.textMuted, shadows: null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: c.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // ── 1. Supabase oturumunu kapat ──
              try {
                await sup.Supabase.instance.client.auth.signOut();
              } catch (_) {}
              // ── 2. Tüm SharedPreferences verilerini sil ──
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
              } catch (_) {}
              // ── 3. AppState session'ını temizle ──
              if (context.mounted) {
                final app = AppScope.of(context);
                app.session = null;
              }
              // ── 4. Ana sayfaya dön ──
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Çıkış', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Doğrulama Bölümü (StatefulWidget — Supabase'den canlı veri) ───

class _VerificationSection extends StatefulWidget {
  const _VerificationSection({required this.c});
  final HgColors c;

  @override
  State<_VerificationSection> createState() => _VerificationSectionState();
}

class _VerificationSectionState extends State<_VerificationSection> {
  bool _isVerified = false;
  VerificationRequest? _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = SupabaseService.user?.id;
    if (userId == null) return;

    final verified = await VerificationService.isVerified(userId);
    final req = await VerificationService.getMyRequest();

    if (mounted) {
      setState(() {
        _isVerified = verified;
        _request = req;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final app = AppScope.of(context);
    final isBusiness = app.session?.accountType == 'business';

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_isVerified) {
      if (isBusiness) {
        statusText = 'Doğrulanmış İşletme ⭐';
        statusColor = c.warning;
        statusIcon = Icons.verified;
      } else {
        statusText = 'Doğrulanmış Hesap ⭐';
        statusColor = c.blue;
        statusIcon = Icons.verified;
      }
    } else if (_request != null && _request!.isPending) {
      statusText = 'İstek inceleniyor…';
      statusColor = c.textMuted;
      statusIcon = Icons.hourglass_top;
    } else if (_request != null &&
        _request!.status == VerificationStatus.rejected) {
      statusText = 'İstek reddedildi';
      statusColor = c.danger;
      statusIcon = Icons.cancel_outlined;
    } else {
      statusText = 'Doğrulanmamış';
      statusColor = c.textMuted;
      statusIcon = Icons.shield_outlined;
    }

    return SettingsSection(
      icon: Icons.verified_user,
      title: 'Doğrulama',
      children: [
        Container(
          padding: const EdgeInsets.all(HgSpace.md),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(HgRadius.md),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: HgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusText,
                        style: HgText.bodyStrong
                            .copyWith(color: statusColor)),
                    if (_request != null &&
                        _request!.isPending &&
                        _request!.expiresAt != null)
                      Text(
                        'Son tarih: ${_request!.expiresAt!.day}.${_request!.expiresAt!.month}.${_request!.expiresAt!.year}',
                        style: HgText.caption
                            .copyWith(color: c.textFaint),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!_isVerified &&
            (_request == null || !_request!.isPending)) ...[
          const SizedBox(height: HgSpace.md),
          GestureDetector(
            onTap: () =>
                _openVerificationSheet(context, isBusiness),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: HgSpace.lg,
                  vertical: HgSpace.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [c.violet, c.blue]),
                borderRadius:
                    BorderRadius.circular(HgRadius.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user,
                      size: 16, color: Colors.white),
                  const SizedBox(width: HgSpace.sm),
                  Text(
                    isBusiness
                        ? 'İşletmeyi Doğrula'
                        : 'Profilini Doğrula',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_isVerified) ...[
          const SizedBox(height: HgSpace.sm),
          Text(
            'Profilinizde ${isBusiness ? "sarı" : "mavi"} doğrulama yıldızı görünmektedir.',
            style:
                HgText.caption.copyWith(color: c.textMuted),
          ),
        ],
      ],
    );
  }

  void _openVerificationSheet(
      BuildContext context, bool isBusiness) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerificationSheet(
        isBusiness: isBusiness,
        onSubmitted: () {
          _load();
          Navigator.pop(context);
        },
      ),
    );
  }
}
