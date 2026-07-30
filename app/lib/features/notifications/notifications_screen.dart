// Hanagram — Bildirimler
//
// Görev/bağlantı/randevu bildirimlerinin kalıcı geçmişi. Uygulama açıkken
// gösterilen anlık SnackBar'lardan farklı olarak burası kalıcı bir liste —
// uygulama kapalıyken olan şeyler de (push ulaştıysa) burada görünür.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/notification_service.dart';
import '../../core/utils.dart';
import 'package:hanagram_design/design.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await NotificationService.getMyNotifications();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  bool get _hasUnread => _items.any((n) => n['is_read'] != true);

  Future<void> _markAllRead() async {
    await NotificationService.markAllAsRead();
    if (mounted) {
      setState(() {
        _items = _items.map((n) => {...n, 'is_read': true}).toList();
      });
    }
  }

  Future<void> _tapItem(int index) async {
    final n = _items[index];
    if (n['is_read'] == true) return;
    final id = n['id'] as String?;
    if (id == null) return;
    setState(() => _items[index] = {...n, 'is_read': true});
    await NotificationService.markAsRead(id);
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'task':
        return CupertinoIcons.checkmark_seal;
      case 'connection_request':
        return CupertinoIcons.person_add;
      case 'connection_accepted':
        return CupertinoIcons.person_2;
      case 'appointment':
        return CupertinoIcons.calendar;
      default:
        return CupertinoIcons.bell;
    }
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
        title: Text('Bildirimler',
            style: HgText.title.copyWith(color: c.text, shadows: null)),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Tümünü okundu işaretle',
                  style: HgText.caption.copyWith(color: c.violet)),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? Center(child: CupertinoActivityIndicator(color: c.violet))
            : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.bell_slash,
                            size: 48, color: c.textFaint),
                        const SizedBox(height: 12),
                        Text('Henüz bildirimin yok',
                            style: HgText.body
                                .copyWith(color: c.textMuted, shadows: null)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: HgSpace.sm),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: c.border.withValues(alpha: 0.5),
                        indent: 76,
                      ),
                      itemBuilder: (_, i) {
                        final n = _items[i];
                        final isRead = n['is_read'] == true;
                        final createdAt =
                            DateTime.tryParse(n['created_at'] as String? ?? '');
                        final now = DateTime.now().millisecondsSinceEpoch;

                        return GestureDetector(
                          onTap: () => _tapItem(i),
                          child: Container(
                            color: isRead
                                ? Colors.transparent
                                : c.violet.withValues(alpha: 0.06),
                            padding: const EdgeInsets.symmetric(
                                horizontal: HgSpace.lg, vertical: HgSpace.md),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: c.violet.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _iconFor(n['type'] as String?),
                                    size: 18,
                                    color: c.violet,
                                  ),
                                ),
                                const SizedBox(width: HgSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['title'] as String? ?? '',
                                        style: HgText.bodyStrong.copyWith(
                                          color: c.text,
                                          shadows: null,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        n['body'] as String? ?? '',
                                        style: HgText.small.copyWith(
                                          color: c.textMuted,
                                          shadows: null,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        createdAt != null
                                            ? relativeTime(
                                                createdAt.millisecondsSinceEpoch,
                                                now)
                                            : '',
                                        style: HgText.caption.copyWith(
                                          color: c.textFaint,
                                          shadows: null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isRead) ...[
                                  const SizedBox(width: HgSpace.sm),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 4),
                                    decoration: BoxDecoration(
                                      color: c.violet,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
