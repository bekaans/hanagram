// Hanagram — uygulama kabuğu
//
// Uyarlanabilir gezinme: telefonda alt bar (liquid glass, scroll'da gizlenir),
// tablet ve masaüstünde yan ray. Aynı kod beş platformda çalışır.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/notification_service.dart';
import '../core/supabase_service.dart';
import 'package:hanagram_design/design.dart';
import '../features/business/business_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_provider.dart';
import 'compose_sheet.dart';
import 'shell_widgets.dart';

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _barHidden = false;
  double _lastScrollOffset = 0;

  StreamSubscription<Map<String, dynamic>>? _taskSub;
  StreamSubscription<Map<String, dynamic>>? _connectionSub;
  StreamSubscription<Map<String, dynamic>>? _appointmentSub;
  StreamSubscription<Map<String, dynamic>>? _messageSub;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.of(context);
      app.loadFeed();
      app.loadDiscover();
      // Tab controller'ı dinle — başka ekranlardan sekme geçişi için
      app.tabController.addListener(_onTabChanged);
      final settings = SettingsScope.of(context);
      _startRealtimeNotifications(app.session?.userId, settings);
      settings.pingOnline();
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    _loadUnreadCount();
  }

  /// Uygulama açıkken canlı bildirim — görev/bağlantı/randevu/mesaj
  /// değişiklikleri anında SnackBar olarak gösterilir (push bildirim ayrı,
  /// bu uygulama içi). Ayarlar'daki "Bildirimleri aç" ana anahtarı kapalıysa
  /// hiçbiri başlamaz; "Mesaj bildirimleri"/"Randevu hatırlatmaları" kendi
  /// bildirim türünü özel olarak kapatır.
  void _startRealtimeNotifications(String? userId, SettingsProvider settings) {
    if (userId == null || userId.isEmpty) return;
    if (!settings.notificationsEnabled) return;

    _taskSub = NotificationService.listenToTasks(userId, (task) {
      _showRealtimeSnack('Yeni görev: ${task['title'] ?? ''}');
    });
    _connectionSub = NotificationService.listenToConnectionRequests(userId, (_) {
      _showRealtimeSnack('Yeni bağlantı isteğin var');
    });
    if (settings.messageNotifications) {
      _messageSub = NotificationService.listenToMessages((message) {
        _handleIncomingMessage(userId, message);
      });
    }
    if (!settings.appointmentReminders) return;
    _appointmentSub = NotificationService.listenToAppointments(userId, (appt) {
      final status = appt['status'] as String?;
      final title = appt['title'] as String? ?? 'Randevu';
      final text = switch (status) {
        'confirmed' => '"$title" randevusu onaylandı',
        'cancelled' => '"$title" randevusu iptal edildi',
        'completed' => '"$title" randevusu tamamlandı',
        _ => '"$title" randevusunda güncelleme var',
      };
      _showRealtimeSnack(text);
    });
  }

  /// Gelen mesajın gerçekten benim bir konuşmama ait olup olmadığını (Realtime
  /// join filtrelemediği için tüm mesajlar akar) ve benden gelmediğini
  /// kontrol edip, öyleyse gönderenin adıyla bildirim gösterir.
  Future<void> _handleIncomingMessage(
      String userId, Map<String, dynamic> message) async {
    final senderId = message['sender_id'] as String?;
    final conversationId = message['conversation_id'] as String?;
    if (senderId == null || senderId == userId || conversationId == null) {
      return;
    }
    try {
      final db = SupabaseService.client;
      final membership = await db
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();
      if (membership == null) return;

      final sender = await db
          .from('users')
          .select('full_name')
          .eq('id', senderId)
          .maybeSingle();
      final senderName = sender?['full_name'] as String? ?? 'Birisi';
      _showRealtimeSnack('$senderName: yeni mesaj');
    } catch (_) {}
  }

  void _showRealtimeSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
    );
    _loadUnreadCount();
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _connectionSub?.cancel();
    _appointmentSub?.cancel();
    _messageSub?.cancel();
    // Listener'ı güvenli kaldır
    try {
      final app = AppScope.of(context);
      app.tabController.removeListener(_onTabChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onTabChanged() {
    final app = AppScope.of(context);
    final newIndex = app.tabController.value;
    if (mounted && newIndex != _index) {
      setState(() {
        _index = newIndex;
        _barHidden = false;
        _lastScrollOffset = 0;
      });
    }
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final offset = notification.metrics.pixels;
      final delta = offset - _lastScrollOffset;
      if (delta > 8 && !_barHidden && offset > 60) {
        setState(() => _barHidden = true);
      } else if (delta < -8 && _barHidden) {
        setState(() => _barHidden = false);
      }
      _lastScrollOffset = offset;
    } else if (notification is ScrollEndNotification) {
      _lastScrollOffset = notification.metrics.pixels;
    }
  }

  // Alt bar: Ana Sayfa + Keşfet + Profil + Mesajlar (+ Yönetim işletme ise)
  List<NavItem> _items(bool pro) => [
        const NavItem(CupertinoIcons.house, CupertinoIcons.house_fill, 'Ana Sayfa'),
        const NavItem(CupertinoIcons.compass, CupertinoIcons.compass_fill, 'Keşfet'),
        const NavItem(CupertinoIcons.person, CupertinoIcons.person_fill, 'Profil'),
        const NavItem(CupertinoIcons.chat_bubble, CupertinoIcons.chat_bubble_fill, 'Mesajlar'),
        if (pro)
          const NavItem(CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_fill, 'Yönetim'),
      ];

  Widget _page(int i, bool pro) {
    final pages = <Widget>[
      const FeedScreen(),
      const DiscoverScreen(),
      const ProfileScreen(),
      const MessagesScreen(),
      if (pro) const BusinessScreen(),
    ];
    return pages[i.clamp(0, pages.length - 1)];
  }

  void _selectTab(int i) {
    SettingsScope.of(context).hapticTap();
    setState(() {
      _index = i;
      _barHidden = false;
      _lastScrollOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final app = AppScope.of(context);
    final session = app.session;
    final pro = session != null && (session.isBusiness || session.isCreator);
    final items = _items(pro);
    final wide = !HgBreak.isPhone(context);

    final body = _page(_index, pro);

    if (wide) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Stack(
          children: [
            Row(
              children: [
                SideRail(
                  items: items,
                  index: _index,
                  onSelect: _selectTab,
                  onCompose: () => _showCreateSheet(context),
                  extended: HgBreak.isDesktop(context),
                ),
                Container(width: 1, color: c.border),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 940),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: HgSpace.lg,
              right: HgSpace.lg,
              child: _NotificationBell(
                count: _unreadCount,
                onTap: _openNotifications,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _onScroll(notification);
              return false;
            },
            child: body,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(HgSpace.md),
                child: _NotificationBell(
                  count: _unreadCount,
                  onTap: _openNotifications,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              items: items,
              index: _index,
              hidden: _barHidden,
              onSelect: _selectTab,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ComposeSheet(),
    );
  }
}

// ─── Bildirim zili — tüm sekmelerde sabit, sağ üstte ───

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
            ),
            child: Icon(CupertinoIcons.bell, size: 18, color: c.text),
          ),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: c.coral,
                  borderRadius: BorderRadius.circular(HgRadius.pill),
                  border: Border.all(color: c.bg, width: 1.5),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.items,
    required this.index,
    required this.hidden,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int index;
  final bool hidden;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: hidden ? 0 : 60,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : c.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : c.border.withValues(alpha: 0.3),
                  width: 0.3,
                ),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 60,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(i),
                            child: _NavCell(
                              item: items[i],
                              active: i == index,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.active});
  final NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final activeColor = isDark ? Colors.white : c.violet;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : c.textMuted;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : c.violet.withValues(alpha: 0.10))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            active ? item.activeIcon : item.icon,
            size: 28,
            color: active ? activeColor : inactiveColor,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? activeColor : inactiveColor,
          ),
        ),
      ],
    );
  }
}
