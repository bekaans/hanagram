// Hanagram — Bağlantı ekranı (Supabase)
//
// Arkadaş/çalışan ekleme, istek gönderme/kabul etme/reddetme.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/connection_service.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final conns = await ConnectionService.getMyConnections();
    final pending = await ConnectionService.getPendingRequests();
    if (mounted) {
      setState(() {
        _connections = conns;
        _pending = pending;
        _loading = false;
      });
    }
  }

  void _showAddSheet() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final c = HgTheme.of(context);
            return Container(
              padding: const EdgeInsets.all(HgSpace.xl),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(HgRadius.xl)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: HgSpace.lg),
                  Text('Kişi Ekle',
                      style: HgText.title
                          .copyWith(color: c.text, shadows: null)),
                  const SizedBox(height: HgSpace.sm),
                  Text('Kullanıcı adı ile arama yapın',
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
                  const SizedBox(height: HgSpace.lg),
                  TextField(
                    controller: searchCtrl,
                    style: HgText.body.copyWith(color: c.text),
                    onChanged: (v) async {
                      if (v.trim().length < 2) {
                        setSheetState(() => results = []);
                        return;
                      }
                      final r =
                          await ConnectionService.searchUsers(v.trim());
                      setSheetState(() => results = r);
                    },
                    decoration: InputDecoration(
                      hintText: 'Kullanıcı adı ara…',
                      hintStyle:
                          HgText.body.copyWith(color: c.textFaint),
                      filled: true,
                      fillColor: c.surfaceAlt,
                      prefixIcon:
                          Icon(Icons.search, color: c.textMuted),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(HgRadius.md),
                        borderSide: BorderSide(color: c.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: HgSpace.md),
                  if (results.isNotEmpty)
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final u = results[i];
                          final name =
                              u['full_name'] as String? ?? '';
                          final uname =
                              u['username'] as String? ?? '';
                          final uid =
                              u['auth_id'] as String? ?? '';
                          return ListTile(
                            leading: Avatar(name: name, size: 36),
                            title: Text(name,
                                style: HgText.body
                                    .copyWith(color: c.text)),
                            subtitle: Text('@$uname',
                                style: HgText.caption
                                    .copyWith(color: c.textMuted)),
                            trailing: Icon(Icons.person_add,
                                color: c.violet),
                            onTap: () async {
                              await ConnectionService.sendRequest(
                                  uid);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'İstek gönderildi!')),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Bağlantılar',
            style: HgText.title
                .copyWith(color: c.text, shadows: null)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: c.violet,
          labelColor: c.violet,
          unselectedLabelColor: c.textMuted,
          tabs: [
            Tab(text: 'Bağlantılar (${_connections.length})'),
            Tab(text: 'İstekler (${_pending.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: c.violet,
        child: Icon(Icons.person_add, color: c.onBrand),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildConnectionList(c),
                _buildPendingList(c),
              ],
            ),
    );
  }

  Widget _buildConnectionList(HgColors c) {
    if (_connections.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.people_outline,
          title: 'Henüz bağlantı yok',
          message: 'Kişi ekleyerek başlayın.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(HgSpace.lg),
        itemCount: _connections.length,
        itemBuilder: (_, i) {
          final conn = _connections[i];
          final u =
              (conn['connected'] as Map?)?.cast<String, dynamic>() ?? {};
          final name = u['full_name'] as String? ?? '';
          final uname = u['username'] as String? ?? '';
          final role = conn['role'] as String? ?? 'friend';

          return HgCard(
            padding: const EdgeInsets.all(HgSpace.md),
            child: Row(
              children: [
                Avatar(name: name, size: 44),
                const SizedBox(width: HgSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: HgText.bodyStrong
                              .copyWith(color: c.text)),
                      Text('@$uname',
                          style: HgText.caption
                              .copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                HgChip(
                  label: switch (role) {
                    'employee' => 'Çalışan',
                    'employer' => 'İşveren',
                    _ => 'Arkadaş',
                  },
                  color: switch (role) {
                    'employee' => c.blue,
                    'employer' => c.coral,
                    _ => c.violet,
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingList(HgColors c) {
    if (_pending.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.mail_outline,
          title: 'Bekleyen istek yok',
          message: 'Yeni bağlantı istekleri burada görünecek.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(HgSpace.lg),
        itemCount: _pending.length,
        itemBuilder: (_, i) {
          final req = _pending[i];
          final sender =
              (req['sender'] as Map?)?.cast<String, dynamic>() ?? {};
          final name = sender['full_name'] as String? ?? '';
          final uname = sender['username'] as String? ?? '';
          final reqId = req['id'] as String? ?? '';

          return HgCard(
            padding: const EdgeInsets.all(HgSpace.md),
            child: Row(
              children: [
                Avatar(name: name, size: 44),
                const SizedBox(width: HgSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: HgText.bodyStrong
                              .copyWith(color: c.text)),
                      Text('@$uname seni eklemek istiyor',
                          style: HgText.caption
                              .copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await ConnectionService.acceptRequest(reqId);
                    _loadData();
                  },
                  icon: Icon(Icons.check_circle,
                      color: c.success, size: 28),
                ),
                IconButton(
                  onPressed: () async {
                    await ConnectionService.rejectRequest(reqId);
                    _loadData();
                  },
                  icon: Icon(Icons.cancel,
                      color: c.danger, size: 28),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
