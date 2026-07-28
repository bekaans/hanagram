// Hanagram Admin — Kaan'ın yönetim paneli
//
// Supabase Auth ile giriş, tüm veriler Supabase'den canlı çekiliyor.
// C++ FFI kaldırıldı — admin paneli %100 Supabase'e bağlı.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import 'core/admin_supabase.dart';
import 'widgets/admin_login.dart';
import 'widgets/admin_rail.dart';
import 'widgets/overview_tab.dart';
import 'widgets/users_tab.dart';
import 'widgets/updates_tab.dart';
import 'widgets/referrals_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdminSupabase.init();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    const colors = HgColors.dark;
    return MaterialApp(
      title: 'Hanagram Admin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(colors, Brightness.dark),
      home: const HgTheme(colors: colors, child: AdminHome()),
    );
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  bool _authed = false;
  bool _loading = false;
  int _tab = 0;

  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _referrals = [];

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  /// Mevcut Supabase session varsa otomatik giriş.
  Future<void> _checkSession() async {
    final user = AdminSupabase.user;
    if (user != null) {
      setState(() {
        _authed = true;
        _loading = true;
      });
      await _refresh();
      if (mounted) setState(() => _loading = false);
    }
  }

  /// E-posta + şifre ile giriş.
  Future<void> _login(String email, String password) async {
    setState(() {
      _loading = true;
      _authed = true;
    });
    await AdminSupabase.signIn(email, password);
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  /// Çıkış.
  Future<void> _logout() async {
    await AdminSupabase.signOut();
    setState(() {
      _authed = false;
      _overview = {};
      _users = [];
      _detail = null;
      _versions = [];
    });
  }

  /// Tüm verileri Supabase'den çek.
  Future<void> _refresh() async {
    try {
      final overviewFuture = AdminSupabase.fetchOverview();
      final usersFuture = AdminSupabase.fetchUsers();
      final versionsFuture = AdminSupabase.fetchVersions();
      final referralsFuture = AdminSupabase.fetchReferrals();

      final results = await Future.wait([
        overviewFuture,
        usersFuture,
        versionsFuture,
        referralsFuture,
      ]);

      if (mounted) {
        setState(() {
          _overview = results[0] as Map<String, dynamic>;
          _users = results[1] as List<Map<String, dynamic>>;
          _versions = results[2] as List<Map<String, dynamic>>;
          _referrals = results[3] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veri çekilemedi: $e'),
            backgroundColor: HgColors.dark.danger,
          ),
        );
      }
    }
  }

  /// Kullanıcı detayını yükle.
  Future<void> _openUser(String authId) async {
    try {
      setState(() => _loading = true);
      final detail = await AdminSupabase.fetchUserDetail(authId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    // Giriş yapılmadıysa login ekranı
    if (!_authed) {
      return AdminLoginScreen(onLogin: _login);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Row(
        children: [
          AdminRail(
            tab: _tab,
            onSelect: (i) => setState(() {
              _tab = i;
              _detail = null;
            }),
            onRefresh: _refresh,
            onLogout: _logout,
          ),
          Container(width: 1, color: c.border),
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: HgSpace.md),
                        Text('Yükleniyor…',
                            style: HgText.small.copyWith(color: c.textMuted)),
                      ],
                    ),
                  )
                : switch (_tab) {
                    0 => OverviewTab(overview: _overview),
                    1 => UsersTab(
                          users: _users,
                          detail: _detail,
                          onOpenUser: _openUser,
                          onBack: () => setState(() => _detail = null),
                        ),
                    2 => UpdatesTab(versions: _versions, onRefresh: _refresh),
                    3 => ReferralsTab(
                          users: _users,
                          referrals: _referrals,
                        ),
                    _ => OverviewTab(overview: _overview),
                  },
          ),
        ],
      ),
    );
  }
}
