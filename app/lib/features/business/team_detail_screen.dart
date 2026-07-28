// Hanagram — ekip detay ekranı
//
// Üye listesi, görevler, CRM, sohbet placeholder.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import 'team_item.dart';
import 'team_sheet.dart';

class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({super.key, required this.team});
  final TeamItem team;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  Future<void> _showInviteSheet() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const InviteMemberSheet(),
    );
    if (name != null && mounted) {
      setState(() => widget.team.members.add(TeamMember(name: name)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final team = widget.team;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text(team.name,
            style: HgText.title.copyWith(color: c.text, shadows: null)),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: c.violet),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ekip sohbeti yakında')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(HgSpace.lg),
        children: [
          // ── Üyeler ──
          _SectionHeader(
            title: 'Üyeler',
            trailing: HgChip(label: '+', color: c.violet, filled: true),
            onTap: _showInviteSheet,
          ),
          const SizedBox(height: HgSpace.sm),
          ...team.members.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: HgSpace.xs),
                child: _MemberTile(member: m),
              )),
          const SizedBox(height: HgSpace.xl),

          // ── Paylaşımlı Görevler ──
          Text('Paylaşımlı Görevler',
              style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.sm),
          if (team.tasks.isEmpty)
            _PlaceholderTile(text: 'Henüz görev yok', c: c)
          else
            ...team.tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: HgSpace.xs),
                  child: _SharedTaskTile(task: t),
                )),
          const SizedBox(height: HgSpace.xl),

          // ── Paylaşımlı CRM ──
          Text('Paylaşımlı CRM',
              style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.sm),
          if (team.crmEntries.isEmpty)
            _PlaceholderTile(text: 'Henüz müşteri yok', c: c)
          else
            ...team.crmEntries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: HgSpace.xs),
                  child: HgCard(
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20, color: c.blue),
                        const SizedBox(width: HgSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.clientName,
                                  style: HgText.bodyStrong.copyWith(
                                      color: c.text, shadows: null)),
                              Text(e.note,
                                  style: HgText.caption.copyWith(
                                      color: c.textMuted, shadows: null)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTap,
  });
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(title,
              style:
                  HgText.heading.copyWith(color: c.text, shadows: null)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return HgCard(
      child: Row(
        children: [
          Avatar(name: member.name, size: 40),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Text(member.name,
                style:
                    HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
          ),
          Text(member.role,
              style:
                  HgText.caption.copyWith(color: c.textMuted, shadows: null)),
        ],
      ),
    );
  }
}

class _SharedTaskTile extends StatelessWidget {
  const _SharedTaskTile({required this.task});
  final SharedTask task;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return HgCard(
      child: Row(
        children: [
          Icon(
            task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 20,
            color: task.isDone ? c.success : c.textMuted,
          ),
          const SizedBox(width: HgSpace.sm),
          Expanded(
            child: Text(task.title,
                style: HgText.body.copyWith(color: c.text, shadows: null)),
          ),
          if (task.assignee != null)
            HgChip(label: task.assignee!, color: c.blue),
        ],
      ),
    );
  }
}

class _PlaceholderTile extends StatelessWidget {
  const _PlaceholderTile({required this.text, required this.c});
  final String text;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return HgCard(
      child: Text(text,
          style: HgText.body.copyWith(color: c.textMuted, shadows: null)),
    );
  }
}
