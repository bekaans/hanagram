// Hanagram — mesajlar
//
// Sohbet listesi. Arama ikonunun yanında yeni mesaj oluşturma butonu.
// Hikaye özelliği askıya alındı.
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';
import 'chat_detail_screen.dart';
import 'new_message_sheet.dart';

// ─── Örnek sohbet verisi ───
final _sampleThreads = [
  ThreadRow(threadId: 't1', otherName: 'Elif Yılmaz', lastText: 'Randevu için saat kaç müsait?',
    lastAt: DateTime.now().subtract(const Duration(minutes: 15)).millisecondsSinceEpoch, unread: true),
  ThreadRow(threadId: 't2', otherName: 'Studio Nova', lastText: 'Çekim fotoğrafını gönderdim, nasıl buldun?',
    lastAt: DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch, unread: true),
  ThreadRow(threadId: 't3', otherName: 'Dr. Ahmet Kaya', lastText: 'Kontrol randevusu için 15 Temmuz uygun mu?',
    lastAt: DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch, unread: false),
  ThreadRow(threadId: 't4', otherName: 'Zeynep Arslan', lastText: 'Kaş laminasyonu için referans fotoğrafı atabilir misin?',
    lastAt: DateTime.now().subtract(const Duration(hours: 6)).millisecondsSinceEpoch, unread: false),
  ThreadRow(threadId: 't5', otherName: 'Hanagram Destek', lastText: 'Hesabınız doğrulandı! Tüm özelliklere erişiminiz açıldı.',
    lastAt: DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch, unread: false),
  ThreadRow(threadId: 't6', otherName: 'Cenk Demir', lastText: 'Antrenman programını paylaştım, bir bak istersen 💪',
    lastAt: DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch, unread: false),
];

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<ThreadRow> _threads = const [];
  bool _isLoading = true;
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    try {
      final app = AppScope.of(context);
      final session = app.session;
      if (session == null) {
        setState(() { _threads = _sampleThreads; _isLoading = false; });
        return;
      }
      final result = app.core.call('message.threads', {'userId': session.userId});
      final items = (result['items'] as List?) ?? const [];
      _threads = items.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return ThreadRow(
          threadId: m['threadId'] as String? ?? '',
          otherName: m['otherName'] as String? ?? '',
          lastText: m['lastText'] as String? ?? '',
          lastAt: (m['lastAt'] as num?)?.toInt() ?? 0,
          unread: m['unread'] as bool? ?? false,
        );
      }).toList();
    } on Exception catch (_) {
      _threads = _sampleThreads;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final allThreads = _threads.isNotEmpty ? _threads : _sampleThreads;
    final query = _searchCtrl.text.toLowerCase();
    final threadsToShow = query.isEmpty
        ? allThreads
        : allThreads.where((t) => t.otherName.toLowerCase().contains(query) || t.lastText.toLowerCase().contains(query)).toList();
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          // ─── Glass üst bar: Mesajlar + arama + yeni mesaj ───
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.md, HgSpace.lg, HgSpace.md),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : c.surface.withValues(alpha: 0.90),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : c.border.withValues(alpha: 0.3),
                      width: 0.3,
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Text('Mesajlar',
                          style: HgText.title.copyWith(color: c.text)),
                      const Spacer(),
                      // Arama
                      GestureDetector(
                        onTap: () => setState(() => _searchOpen = !_searchOpen),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _searchOpen
                                ? c.violet.withValues(alpha: 0.15)
                                : c.surfaceAlt.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _searchOpen ? CupertinoIcons.xmark : CupertinoIcons.search,
                            size: 17,
                            color: _searchOpen ? c.violet : c.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Yeni mesaj oluştur
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const NewMessageSheet(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: c.violet.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(CupertinoIcons.pencil, size: 17, color: c.violet),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Arama alanı (açıkken) ───
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(HgSpace.lg, HgSpace.sm, HgSpace.lg, 0),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: HgText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'Sohbet ara...',
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
                onChanged: (q) => setState(() {}),
              ),
            ),

          // ─── Sohbet listesi ───
          Expanded(
            child: _isLoading
                ? Center(child: CupertinoActivityIndicator(color: c.violet))
                : RefreshIndicator(
                    onRefresh: _loadThreads,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: HgSpace.sm),
                      itemCount: threadsToShow.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1, thickness: 0.5,
                        color: c.border.withValues(alpha: 0.5),
                        indent: 76,
                      ),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatDetailScreen(
                                threadId: threadsToShow[i].threadId,
                                otherName: threadsToShow[i].otherName,
                              ),
                            ),
                          );
                        },
                        child: _ThreadTile(thread: threadsToShow[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Sohbet satırı ───

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});
  final ThreadRow thread;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;

    return Container(
      color: thread.unread ? c.violet.withValues(alpha: 0.06) : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: HgSpace.md),
        child: Row(
          children: [
            Stack(
              children: [
                Avatar(name: thread.otherName, size: 48),
                if (thread.unread)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: c.violet,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: HgSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(thread.otherName,
                      style: HgText.bodyStrong.copyWith(
                          color: thread.unread ? c.text : c.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(thread.lastText,
                      style: HgText.small.copyWith(
                        color: thread.unread ? c.text : c.textMuted,
                        fontWeight: thread.unread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: HgSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(relativeTime(thread.lastAt, now),
                    style: HgText.caption.copyWith(
                        color: thread.unread ? c.violet : c.textFaint)),
                const SizedBox(height: 4),
                if (!thread.unread)
                  Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: c.textFaint)
                else
                  Icon(CupertinoIcons.circle_fill, size: 14, color: c.violet),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ThreadRow {
  final String threadId;
  final String otherName;
  final String lastText;
  final int lastAt;
  final String unreadId;
  final bool unread;

  const ThreadRow({
    required this.threadId,
    required this.otherName,
    required this.lastText,
    required this.lastAt,
    required this.unread,
  }) : unreadId = '';

  bool get isUnread => unread;
}
