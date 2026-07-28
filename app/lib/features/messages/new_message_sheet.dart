// Hanagram — yeni mesaj oluşturma sayfası
//
// Tüm kullanıcıları ve sayfaları listeler. Öncelik takipçiler/takip ettikleri.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final app = AppScope.of(context);
      final session = app.session;
      if (session != null) {
        final result = app.core.call('user.list', {'userId': session.userId, 'limit': 50});
        final items = (result['items'] as List?) ?? const [];
        _users = items.map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return _UserRow(
            userId: m['id'] as String? ?? '',
            name: m['name'] as String? ?? '',
            handle: m['handle'] as String? ?? '',
            isFollowing: m['isFollowing'] == true,
            isFollower: m['isFollower'] == true,
          );
        }).toList();
      }
    } on Exception catch (_) {
      // Fallback örnek veri
      _users = _sampleUsers;
    }
    // Öncelik sıralaması: takip ettikleri → takipçileri → diğerleri
    _users.sort((a, b) {
      if (a.isFollowing && !b.isFollowing) return -1;
      if (!a.isFollowing && b.isFollowing) return 1;
      if (a.isFollower && !b.isFollower) return -1;
      if (!a.isFollower && b.isFollower) return 1;
      return 0;
    });
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final query = _searchCtrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? _users
        : _users.where((u) =>
            u.name.toLowerCase().contains(query) ||
            u.handle.toLowerCase().contains(query)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                padding: const EdgeInsets.fromLTRB(HgSpace.lg, 0, HgSpace.lg, HgSpace.sm),
                child: Row(
                  children: [
                    Text('Yeni mesaj', style: HgText.title.copyWith(color: c.text)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(CupertinoIcons.xmark_circle_fill, size: 24, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              // Arama
              Padding(
                padding: const EdgeInsets.fromLTRB(HgSpace.lg, 0, HgSpace.lg, HgSpace.sm),
                child: TextField(
                  controller: _searchCtrl,
                  style: HgText.body.copyWith(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Kişi veya sayfa ara...',
                    hintStyle: HgText.body.copyWith(color: c.textFaint),
                    prefixIcon: Icon(CupertinoIcons.search, size: 18, color: c.textMuted),
                    filled: true,
                    fillColor: c.surfaceAlt.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: HgSpace.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(HgRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              // Kullanıcı listesi
              Expanded(
                child: _isLoading
                    ? Center(child: CupertinoActivityIndicator(color: c.violet))
                    : filtered.isEmpty
                        ? Center(
                            child: Text('Kişi bulunamadı',
                                style: HgText.body.copyWith(color: c.textMuted)),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1, thickness: 0.5,
                              color: c.border.withValues(alpha: 0.5),
                              indent: 76,
                            ),
                            itemBuilder: (_, i) {
                              final u = filtered[i];
                              return _UserTile(
                                user: u,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ChatDetailScreen(
                                        threadId: u.userId,
                                        otherName: u.name,
                                      ),
                                    ),
                                  );
                                },
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
        padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: HgSpace.md),
        child: Row(
          children: [
            Avatar(name: user.name, size: 48),
            const SizedBox(width: HgSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(user.name,
                            style: HgText.bodyStrong.copyWith(color: c.text),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (user.isFollowing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.violet.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Takip ediyor',
                              style: TextStyle(fontSize: 10, color: c.violet, fontWeight: FontWeight.w600)),
                        ),
                      ],
                      if (user.isFollower && !user.isFollowing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Takipçi',
                              style: TextStyle(fontSize: 10, color: c.success, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('@${user.handle}',
                      style: HgText.small.copyWith(color: c.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: c.textFaint),
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
    this.isFollowing = false,
    this.isFollower = false,
  });

  final String userId;
  final String name;
  final String handle;
  final bool isFollowing;
  final bool isFollower;
}

// ─── Örnek veri ───
final _sampleUsers = [
  const _UserRow(userId: 'u1', name: 'Elif Yılmaz', handle: 'elif.yilmaz', isFollowing: true),
  const _UserRow(userId: 'u2', name: 'Studio Nova', handle: 'studionova', isFollowing: true),
  const _UserRow(userId: 'u3', name: 'Dr. Ahmet Kaya', handle: 'dr.ahmet', isFollower: true),
  const _UserRow(userId: 'u4', name: 'Zeynep Arslan', handle: 'zeynep.arslan', isFollower: true),
  const _UserRow(userId: 'u5', name: 'Cenk Demir', handle: 'cenk.demir'),
  const _UserRow(userId: 'u6', name: 'FitLife Stüdyo', handle: 'fitlife'),
  const _UserRow(userId: 'u7', name: 'Merve Demir', handle: 'mervedemir'),
  const _UserRow(userId: 'u8', name: 'Hanagram Destek', handle: 'hanagramdestek'),
];
