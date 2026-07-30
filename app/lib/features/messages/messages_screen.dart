// Hanagram — mesajlar
//
// Sohbet listesi. Arama ikonunun yanında yeni mesaj oluşturma butonu.
// Supabase real-time ile güncellenir.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/message_models.dart';
import '../../core/message_service.dart';
import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';
import 'chat_detail_screen.dart';
import 'new_message_sheet.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<MessageThread> _threads = const [];
  bool _isLoading = true;
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();
  StreamSubscription<void>? _threadsSub;

  @override
  void initState() {
    super.initState();
    _loadThreads();
    _subscribeThreads();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _threadsSub?.cancel();
    MessageService.unsubscribeThreads();
    super.dispose();
  }

  void _subscribeThreads() {
    final session = AppScope.of(context).session;
    if (session == null) return;

    _threadsSub?.cancel();
    _threadsSub = MessageService.subscribeToThreads().listen((_) {
      if (mounted) _loadThreads();
    });
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    try {
      final result = await MessageService.getThreads();
      if (mounted) {
        setState(() {
          _threads = result;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final query = _searchCtrl.text.toLowerCase();
    final threadsToShow = query.isEmpty
        ? _threads
        : _threads
            .where((t) =>
                t.otherUserName.toLowerCase().contains(query) ||
                t.lastMessage.toLowerCase().contains(query))
            .toList();
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
                padding: const EdgeInsets.fromLTRB(
                    HgSpace.lg, HgSpace.md, HgSpace.lg, HgSpace.md),
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
                          style: HgText.title
                              .copyWith(color: c.text, shadows: null)),
                      const Spacer(),
                      // Arama
                      GestureDetector(
                        onTap: () =>
                            setState(() => _searchOpen = !_searchOpen),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _searchOpen
                                ? c.violet.withValues(alpha: 0.15)
                                : c.surfaceAlt.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _searchOpen
                                ? CupertinoIcons.xmark
                                : CupertinoIcons.search,
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
                          child: Icon(CupertinoIcons.pencil,
                              size: 17, color: c.violet),
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
              padding: const EdgeInsets.fromLTRB(
                  HgSpace.lg, HgSpace.sm, HgSpace.lg, 0),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: HgText.body.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'Sohbet ara...',
                  hintStyle:
                      HgText.body.copyWith(color: c.textFaint, shadows: null),
                  prefixIcon: Icon(CupertinoIcons.search,
                      size: 18, color: c.textMuted),
                  filled: true,
                  fillColor: c.surfaceAlt.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: HgSpace.lg, vertical: HgSpace.md),
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
                ? Center(
                    child: CupertinoActivityIndicator(color: c.violet))
                : _threads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.chat_bubble_2,
                                size: 48, color: c.textFaint),
                            const SizedBox(height: 12),
                            Text('Henüz mesajınız yok',
                                style: HgText.body
                                    .copyWith(color: c.textMuted, shadows: null)),
                            const SizedBox(height: 4),
                            Text('Yeni bir sohbet başlatın',
                                style: HgText.caption
                                    .copyWith(color: c.textFaint, shadows: null)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadThreads,
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(vertical: HgSpace.sm),
                          itemCount: threadsToShow.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: c.border.withValues(alpha: 0.5),
                            indent: 76,
                          ),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatDetailScreen(
                                    threadId:
                                        threadsToShow[i].conversationId,
                                    otherName:
                                        threadsToShow[i].otherUserName,
                                  ),
                                ),
                              );
                            },
                            child:
                                _ThreadTile(thread: threadsToShow[i]),
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
  final MessageThread thread;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastAtMs = thread.lastAt.millisecondsSinceEpoch;
    final hasUnread = thread.unreadCount > 0;

    return Container(
      color: hasUnread
          ? c.violet.withValues(alpha: 0.06)
          : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: HgSpace.lg, vertical: HgSpace.md),
        child: Row(
          children: [
            Stack(
              children: [
                Avatar(name: thread.otherUserName, size: 48),
                if (hasUnread)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
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
                  Text(thread.otherUserName,
                      style: HgText.bodyStrong.copyWith(
                          color: hasUnread ? c.text : c.textMuted,
                          shadows: null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(thread.lastMessage,
                      style: HgText.small.copyWith(
                        color: hasUnread ? c.text : c.textMuted,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.normal,
                        shadows: null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: HgSpace.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(relativeTime(lastAtMs, now),
                    style: HgText.caption.copyWith(
                        color: hasUnread ? c.violet : c.textFaint,
                        shadows: null)),
                const SizedBox(height: 4),
                if (!hasUnread)
                  Icon(CupertinoIcons.checkmark_circle_fill,
                      size: 14, color: c.textFaint)
                else
                  Icon(CupertinoIcons.circle_fill,
                      size: 14, color: c.violet),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
