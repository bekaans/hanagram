// Hanagram — sohbet detay ekranı
//
// WhatsApp hissiyatında, ama Hanagram'a özgü cam/liquid tasarım.
// Supabase real-time ile çalışıyor.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/message_models.dart';
import '../../core/message_service.dart';
import 'package:hanagram_design/design.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.threadId,
    required this.otherName,
  });

  final String threadId;
  final String otherName;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription<ChatMessage>? _msgSub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _msgSub?.cancel();
    MessageService.unsubscribeMessages();
    super.dispose();
  }

  void _subscribeMessages() {
    _msgSub?.cancel();
    _msgSub =
        MessageService.subscribeToMessages(widget.threadId).listen((msg) {
      if (!mounted) return;
      setState(() => _messages.add(msg));
      _scrollToBottom();
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final msgs = await MessageService.getMessages(widget.threadId);
      if (mounted) {
        setState(() {
          _messages.addAll(msgs);
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead() async {
    await MessageService.markAsRead(widget.threadId);
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    final success =
        await MessageService.sendMessage(widget.threadId, text);

    if (!success && mounted) {
      // Hata durumunda mesajı geri yükle
      _msgCtrl.text = text;
    }

    if (mounted) setState(() => _isSending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : c.surface.withValues(alpha: 0.90);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : c.border.withValues(alpha: 0.3);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: glassBg,
                border: Border(
                  bottom: BorderSide(color: glassBorder, width: 0.3),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.back,
                          size: 20, color: c.text),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Avatar(name: widget.otherName, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.otherName,
                              style: HgText.bodyStrong
                                  .copyWith(color: c.text, shadows: null),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('Çevrimiçi',
                              style: HgText.caption.copyWith(
                                  color: c.success, shadows: null)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.phone,
                          size: 20, color: c.textMuted),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.video_camera,
                          size: 20, color: c.textMuted),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CupertinoActivityIndicator(color: c.violet))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.chat_bubble,
                                size: 40, color: c.textFaint),
                            const SizedBox(height: 12),
                            Text('Henüz mesaj yok',
                                style: HgText.body.copyWith(
                                    color: c.textMuted, shadows: null)),
                            const SizedBox(height: 4),
                            Text('İlk mesajı gönderin!',
                                style: HgText.caption.copyWith(
                                    color: c.textFaint, shadows: null)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: HgSpace.md, vertical: HgSpace.sm),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                            msg: _messages[i], c: c),
                      ),
          ),
          // Alt giriş alanı — glass efektli
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  HgSpace.md,
                  HgSpace.sm,
                  HgSpace.md,
                  HgSpace.sm +
                      MediaQuery.of(context).viewPadding.bottom,
                ),
                decoration: BoxDecoration(
                  color: glassBg,
                  border: Border(
                    top: BorderSide(color: glassBorder, width: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(CupertinoIcons.smiley,
                          size: 20, color: c.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          style:
                              HgText.body.copyWith(color: c.text),
                          decoration: InputDecoration(
                            hintText: 'Mesaj yaz...',
                            hintStyle: HgText.body.copyWith(
                                color: c.textFaint, shadows: null),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isSending
                              ? c.textFaint
                              : c.violet,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                            CupertinoIcons.arrow_up,
                            size: 18,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mesaj baloncuğu ───

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, required this.c});
  final ChatMessage msg;
  final HgColors c;

  String _timeStr() {
    final h = msg.createdAt.hour.toString().padLeft(2, '0');
    final m = msg.createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Avatar(name: 'A', size: 24),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? c.violet.withValues(alpha: 0.85)
                    : c.surfaceAlt.withValues(alpha: 0.7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg.content,
                    style: HgText.body.copyWith(
                      color: isMe ? Colors.white : c.text,
                      fontSize: 14.5,
                      shadows: null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeStr(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.6)
                          : c.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Icon(CupertinoIcons.checkmark_circle_fill,
                size: 14, color: c.violet),
          ],
        ],
      ),
    );
  }
}
