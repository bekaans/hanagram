// Hanagram Admin — kullanıcılar sekmesi (liste + detay)
//
// Tüm kullanıcılar Supabase'den çekiliyor. Detay tıklandığında kullanıcının
// görevleri, randevuları, CRM kayıtları ve bağlantıları görüntüleniyor.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class UsersTab extends StatelessWidget {
  const UsersTab({
    super.key,
    required this.users,
    required this.detail,
    required this.onOpenUser,
    required this.onBack,
  });

  final List<Map<String, dynamic>> users;
  final Map<String, dynamic>? detail;
  final ValueChanged<String> onOpenUser;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (detail != null) return _userDetail(context);
    return _userList(context);
  }

  // ─── Kullanıcı listesi ───

  Widget _userList(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(HgSpace.xl),
          child: Row(
            children: [
              Text('Kullanıcılar',
                  style: HgText.display.copyWith(color: c.text)),
              const SizedBox(width: HgSpace.md),
              HgChip(label: '${users.length}', color: c.violet),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'Henüz kullanıcı yok',
                  message: 'Kayıt olan ilk üye burada görünecek.',
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: HgSpace.xl),
                  itemCount: users.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: HgSpace.sm),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final name = u['full_name'] as String? ?? '';
                    final username = u['username'] as String? ?? '';
                    final accType = u['account_type'] as String? ?? 'personal';
                    final createdAt = u['created_at'] as String? ?? '';
                    return HgCard(
                      onTap: () => onOpenUser(u['auth_id'] as String? ?? ''),
                      padding:
                          const EdgeInsets.all(HgSpace.md),
                      child: Row(
                        children: [
                          Avatar(name: name, size: 38),
                          const SizedBox(width: HgSpace.md),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: HgText.bodyStrong
                                        .copyWith(color: c.text)),
                                Text('@$username',
                                    style: HgText.caption
                                        .copyWith(
                                            color: c.textMuted)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: HgChip(
                              label: switch (accType) {
                                'business' => 'İşletme',
                                'creator' => 'Üretici',
                                _ => 'Kişisel',
                              },
                              color: switch (accType) {
                                'business' => c.blue,
                                'creator' => c.coral,
                                _ => c.violet,
                              },
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(_formatDate(createdAt),
                                style: HgText.small
                                    .copyWith(color: c.textMuted)),
                          ),
                          Icon(Icons.chevron_right,
                              size: 18, color: c.textFaint),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ─── Kullanıcı detayı ───

  Widget _userDetail(BuildContext context) {
    final c = HgTheme.of(context);
    final profile =
        (detail!['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final tasks = (detail!['tasks'] as List?) ?? [];
    final appointments = (detail!['appointments'] as List?) ?? [];
    final crm = (detail!['crm'] as List?) ?? [];
    final connections = (detail!['connections'] as List?) ?? [];

    final name = profile['full_name'] as String? ?? '';
    final username = profile['username'] as String? ?? '';
    final bio = profile['bio'] as String? ?? '';
    final sector = profile['sector'] as String? ?? '';
    final accType = profile['account_type'] as String? ?? 'personal';
    final avatarUrl = profile['avatar_url'] as String?;
    final createdAt = profile['created_at'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(HgSpace.xl),
      children: [
        // ─── Başlık ───
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back, color: c.textMuted),
            ),
            if (avatarUrl != null && avatarUrl.isNotEmpty)
              CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(avatarUrl),
              )
            else
              Avatar(name: name, size: 52, gradient: true),
            const SizedBox(width: HgSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: HgText.title.copyWith(color: c.text)),
                  Text('@$username',
                      style: HgText.small.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            HgChip(
              label: switch (accType) {
                'business' => 'İşletme',
                'creator' => 'Üretici',
                _ => 'Kişisel',
              },
              color: switch (accType) {
                'business' => c.blue,
                'creator' => c.coral,
                _ => c.violet,
              },
            ),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        if (bio.isNotEmpty)
          Text(bio, style: HgText.body.copyWith(color: c.textMuted)),
        if (sector.isNotEmpty) ...[
          const SizedBox(height: HgSpace.xs),
          Text('Sektör: $sector',
              style: HgText.small.copyWith(color: c.textFaint)),
        ],
        Text('Katılım: ${_formatDate(createdAt)}',
            style: HgText.small.copyWith(color: c.textFaint)),
        const SizedBox(height: HgSpace.xl),

        // ─── Sayısal Özet ───
        Wrap(
          spacing: HgSpace.md,
          runSpacing: HgSpace.md,
          children: [
            _stat(c, 'Görev', '${tasks.length}',
                Icons.task_alt, c.violet),
            _stat(c, 'Randevu', '${appointments.length}',
                Icons.event_outlined, c.blue),
            _stat(c, 'CRM', '${crm.length}',
                Icons.receipt_long_outlined, c.coral),
            _stat(c, 'Bağlantı', '${connections.length}',
                Icons.group_outlined, c.warning),
          ],
        ),
        const SizedBox(height: HgSpace.xl),

        // ─── Görevler ───
        _sectionHeader(c, 'Görevler', tasks.length, Icons.task_alt),
        const SizedBox(height: HgSpace.sm),
        if (tasks.isEmpty)
          _empty(c, 'Görev yok')
        else
          for (final t in tasks)
            _taskTile(c, t as Map<String, dynamic>),
        const SizedBox(height: HgSpace.xl),

        // ─── Randevular ───
        _sectionHeader(c, 'Randevular', appointments.length,
            Icons.event_outlined),
        const SizedBox(height: HgSpace.sm),
        if (appointments.isEmpty)
          _empty(c, 'Randevu yok')
        else
          for (final a in appointments)
            _appointmentTile(c, a as Map<String, dynamic>),
        const SizedBox(height: HgSpace.xl),

        // ─── CRM Kayıtları ───
        _sectionHeader(c, 'CRM Kayıtları', crm.length,
            Icons.receipt_long_outlined),
        const SizedBox(height: HgSpace.sm),
        if (crm.isEmpty)
          _empty(c, 'CRM kaydı yok')
        else
          for (final e in crm)
            _crmTile(c, e as Map<String, dynamic>),
        const SizedBox(height: HgSpace.xl),

        // ─── Bağlantılar ───
        _sectionHeader(c, 'Bağlantılar', connections.length,
            Icons.group_outlined),
        const SizedBox(height: HgSpace.sm),
        if (connections.isEmpty)
          _empty(c, 'Bağlantı yok')
        else
          for (final conn in connections)
            _connectionTile(c, conn as Map<String, dynamic>),
        const SizedBox(height: HgSpace.xl),
      ],
    );
  }

  // ─── Yardımcı Widget'lar ───

  static Widget _sectionHeader(
      HgColors c, String title, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: c.violet),
        const SizedBox(width: HgSpace.sm),
        Text(title, style: HgText.heading.copyWith(color: c.text)),
        const SizedBox(width: HgSpace.sm),
        HgChip(label: '$count', color: c.violet),
      ],
    );
  }

  static Widget _empty(HgColors c, String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
      child: Text(msg, style: HgText.small.copyWith(color: c.textFaint)),
    );
  }

  static Widget _taskTile(HgColors c, Map<String, dynamic> t) {
    final title = t['title'] as String? ?? '';
    final status = t['status'] as String? ?? 'pending';
    final priority = t['priority'] as String? ?? 'medium';
    final dueDate = t['due_date'] as String? ?? '';
    final creatorName =
        (t['creator'] as Map?)?['full_name'] as String? ?? '';
    final assigneeName =
        (t['assignee'] as Map?)?['full_name'] as String? ?? '';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        HgText.bodyStrong.copyWith(color: c.text)),
                if (creatorName.isNotEmpty || assigneeName.isNotEmpty)
                  Text(
                    '${creatorName.isNotEmpty ? "Oluşturan: $creatorName" : ""}'
                    '${assigneeName.isNotEmpty ? " · Atanan: $assigneeName" : ""}',
                    style:
                        HgText.caption.copyWith(color: c.textMuted),
                  ),
              ],
            ),
          ),
          HgChip(
            label: _statusLabel(status),
            color: _statusColor(c, status),
          ),
          const SizedBox(width: HgSpace.sm),
          HgChip(
            label: _priorityLabel(priority),
            color: _priorityColor(c, priority),
          ),
          if (dueDate.isNotEmpty) ...[
            const SizedBox(width: HgSpace.sm),
            Text(dueDate,
                style:
                    HgText.caption.copyWith(color: c.textFaint)),
          ],
        ],
      ),
    );
  }

  static Widget _appointmentTile(
      HgColors c, Map<String, dynamic> a) {
    final title = a['title'] as String? ?? '';
    final date = a['date'] as String? ?? '';
    final startTime = a['start_time'] as String? ?? '';
    final status = a['status'] as String? ?? 'pending';
    final attendeeName =
        (a['attendee'] as Map?)?['full_name'] as String? ?? '';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        HgText.bodyStrong.copyWith(color: c.text)),
                if (attendeeName.isNotEmpty)
                  Text('Katılımcı: $attendeeName',
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
              ],
            ),
          ),
          if (date.isNotEmpty)
            Text('$date $startTime',
                style:
                    HgText.small.copyWith(color: c.textMuted)),
          const SizedBox(width: HgSpace.sm),
          HgChip(
            label: _statusLabel(status),
            color: _statusColor(c, status),
          ),
        ],
      ),
    );
  }

  static Widget _crmTile(HgColors c, Map<String, dynamic> e) {
    final type = e['type'] as String? ?? '';
    final title = e['title'] as String? ?? '';
    final amount = (e['amount'] as num?) ?? 0;
    final customer = e['customer_name'] as String? ?? '';
    final date = e['date'] as String? ?? '';
    final status = e['status'] as String? ?? '';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Icon(
            type == 'sale'
                ? Icons.attach_money
                : Icons.event_outlined,
            size: 17,
            color: type == 'sale' ? c.success : c.blue,
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        HgText.bodyStrong.copyWith(color: c.text)),
                if (customer.isNotEmpty)
                  Text(customer,
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
              ],
            ),
          ),
          if (amount > 0)
            Text('₺${amount.toStringAsFixed(0)}',
                style: HgText.bodyStrong
                    .copyWith(color: c.success)),
          const SizedBox(width: HgSpace.sm),
          if (date.isNotEmpty)
            Text(date.substring(0, 10),
                style:
                    HgText.small.copyWith(color: c.textFaint)),
          const SizedBox(width: HgSpace.sm),
          HgChip(
            label: status,
            color: status == 'completed'
                ? c.success
                : c.textMuted,
          ),
        ],
      ),
    );
  }

  static Widget _connectionTile(
      HgColors c, Map<String, dynamic> conn) {
    final connected =
        (conn['connected'] as Map?)?.cast<String, dynamic>() ?? {};
    final connName = connected['full_name'] as String? ?? '';
    final connUsername = connected['username'] as String? ?? '';
    final status = conn['status'] as String? ?? 'pending';
    final role = conn['role'] as String? ?? 'friend';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Avatar(name: connName, size: 32),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(connName,
                    style:
                        HgText.bodyStrong.copyWith(color: c.text)),
                Text('@$connUsername',
                    style: HgText.caption
                        .copyWith(color: c.textMuted)),
              ],
            ),
          ),
          HgChip(
            label: role == 'employee'
                ? 'Çalışan'
                : role == 'employer'
                    ? 'İşveren'
                    : 'Arkadaş',
            color: role == 'employee'
                ? c.blue
                : role == 'employer'
                    ? c.coral
                    : c.violet,
          ),
          const SizedBox(width: HgSpace.sm),
          HgChip(
            label: status == 'accepted' ? 'Kabul' : status,
            color: status == 'accepted' ? c.success : c.warning,
          ),
        ],
      ),
    );
  }

  // ─── Yardımcı Fonksiyonlar ───

  static String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}.'
          '${dt.month.toString().padLeft(2, '0')}.'
          '${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  static String _statusLabel(String s) => switch (s) {
        'pending' => 'Bekliyor',
        'accepted' => 'Kabul',
        'in_progress' => 'Devam',
        'completed' => 'Tamam',
        'rejected' => 'Red',
        'confirmed' => 'Onay',
        'cancelled' => 'İptal',
        _ => s,
      };

  static Color _statusColor(HgColors c, String s) => switch (s) {
        'completed' || 'confirmed' => c.success,
        'rejected' || 'cancelled' => c.danger,
        'in_progress' => c.blue,
        'accepted' => c.violet,
        _ => c.textMuted,
      };

  static String _priorityLabel(String p) => switch (p) {
        'low' => 'Düşük',
        'medium' => 'Normal',
        'high' => 'Yüksek',
        'urgent' => 'Acil',
        _ => p,
      };

  static Color _priorityColor(HgColors c, String p) => switch (p) {
        'urgent' => c.danger,
        'high' => c.coral,
        'medium' => c.warning,
        _ => c.textMuted,
      };

  static Widget _stat(HgColors c, String label, String value,
      IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(HgSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(HgRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: HgSpace.md),
          Text(value,
              style:
                  HgText.display.copyWith(color: c.text, fontSize: 28)),
          Text(label,
              style: HgText.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}
