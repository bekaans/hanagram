// Hanagram — yeni mesaj oluşturma sayfası
//
// Supabase'den kişi listesi. Mevcut DM'i bulur veya yeni oluşturur.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/message_service.dart';
import 'package:hanagram_design/design.dart';
import 'chat_detail_screen.dart';

class NewMessageSheet extends StatefulWidget {
  const NewMessageSheet({super.key});

  @override
  State<NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<NewMessageSheet> {
  final _searchCtrl = TextEditingController();
  List<_UserRow> _users = [];
  List<_UserRow> _connections = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    setState(() => _isLoading = true);
    try {
      final result = await MessageService.getConnections();
      _connections = result
          .map((m) => _UserRow(
                userId: m['id'] as String? ?? '',
                name: m['full_name'] as String? ?? '',
                handle: m['username'] as String? ?? '',
              ))
          .toList();
      _users = _connections;
    } catch (_) {
      _users = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _users = _connections;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await MessageService.searchUsers(query);
      _users = result
          .map((m) => _UserRow(
                userId: m['id'] as String? ?? '',
                name: m['full_name'] as String? ?? '',
                handle: m['username'] as String? ?? '',
              ))
          .toList();
    } catch (_) {}
    if (mounted) setState(() => _isSearching = false);
  }

  Future<void> _openChat(_UserRow user) async {
    // DM conversation bul veya oluştur
    final convId = await MessageService.findOrCreateDm(user.userId);
    if (convId == null || !mounted) return;

    if (!context.mounted) return;
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          threadId: convId,
          otherName: user.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final query = _searchCtrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? _users
        : _users
            .where((u) =>
                u.name.toLowerCase().contains(query) ||
                u.handle.toLowerCase().contains(query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Üst tutamaç
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: c.textFaint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    HgSpace.lg, 0, HgSpace.lg, HgSpace.sm),
                child: Row(
                  children: [
                    Text('Yeni mesaj',
                        style: HgText.title
                            .copyWith(color: c.text, shadows: null)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(CupertinoIcons.xmark_circle_fill,
                          size: 24, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              // Arama
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    HgSpace.lg, 0, HgSpace.lg, HgSpace.sm),
                child: TextField(
                  controller: _searchCtrl,
                  style: HgText.body.copyWith(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Kişi ara...',
                    hintStyle: HgText.body
                        .copyWith(color: c.textFaint, shadows: null),
                    prefixIcon: Icon(CupertinoIcons.search,
                        size: 18, color: c.textMuted),
                    filled: true,
                    fillColor:
                        c.surfaceAlt.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: HgSpace.lg,
                        vertical: HgSpace.md),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(HgRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (q) {
                    setState(() {});
                    _searchUsers(q);
                  },
                ),
              ),
              // Kullanıcı listesi
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CupertinoActivityIndicator(
                            color: c.violet))
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.person_2,
                                    size: 40, color: c.textFaint),
                                const SizedBox(height: 12),
                                Text(
                                  _isSearching
                                      ? 'Arama yapılıyor...'
                                      : 'Kişi bulunamadı',
                                  style: HgText.body.copyWith(
                                      color: c.textMuted,
                                      shadows: null),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              thickness: 0.5,
                              color:
                                  c.border.withValues(alpha: 0.5),
                              indent: 76,
                            ),
                            itemBuilder: (_, i) {
                              final u = filtered[i];
                              return _UserTile(
                                user: u,
                                onTap: () => _openChat(u),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Kullanıcı satırı ───

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});
  final _UserRow user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: HgSpace.lg, vertical: HgSpace.md),
        child: Row(
          children: [
            Avatar(name: user.name, size: 48),
            const SizedBox(width: HgSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: HgText.bodyStrong
                          .copyWith(color: c.text, shadows: null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('@${user.handle}',
                      style: HgText.small
                          .copyWith(color: c.textMuted, shadows: null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 16, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

class _UserRow {
  const _UserRow({
    required this.userId,
    required this.name,
    required this.handle,
  });

  final String userId;
  final String name;
  final String handle;
}
