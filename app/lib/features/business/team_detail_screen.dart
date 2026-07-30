// Hanagram — ekip detay ekranı
//
// Üye listesi, görevler, CRM. Veri Supabase business_groups/group_members'tan gelir.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/message_service.dart';
import '../../core/team_service.dart';
import '../messages/chat_detail_screen.dart';
import 'team_item.dart';
import 'team_sheet.dart';

class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({super.key, required this.team});
  final TeamItem team;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  late List<TeamMember> _members = widget.team.members;
  List<SharedTask> _tasks = const [];
  List<CrmEntry> _crmEntries = const [];
  bool _isLoading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      TeamService.getTeamTasks(widget.team.id),
      TeamService.getTeamCrm(widget.team.id),
    ]);
    _tasks = (results[0]).map((t) => SharedTask(
          title: t['title'] as String? ?? '',
          assignee: t['assignee'] as String?,
          isDone: t['isDone'] as bool? ?? false,
        )).toList();
    _crmEntries = (results[1]).map((e) => CrmEntry(
          clientName: e['clientName'] as String? ?? '',
          note: e['note'] as String? ?? '',
        )).toList();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _showInviteSheet() async {
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const InviteMemberSheet(),
    );
    if (picked == null || !mounted) return;

    final ok = await TeamService.addMember(widget.team.id, picked['userId']!);
    if (!mounted) return;
    if (ok) {
      setState(() => _members = [
            ..._members,
            TeamMember(
              name: picked['name'] ?? '',
              userId: picked['userId'] ?? '',
            ),
          ]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eklenemedi, tekrar deneyin.')),
      );
    }
  }

  Future<void> _openTeamChat() async {
    if (_opening) return;
    setState(() => _opening = true);
    final memberIds =
        _members.map((m) => m.userId).where((id) => id.isNotEmpty).toList();
    final convId = await MessageService.findOrCreateTeamConversation(
      widget.team.id,
      widget.team.name,
      memberIds,
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (convId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet açılamadı, tekrar deneyin.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          threadId: convId,
          otherName: widget.team.name,
        ),
      ),
    );
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
            icon: _opening
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.violet))
                : Icon(Icons.chat_bubble_outline, color: c.violet),
            onPressed: _opening ? null : _openTeamChat,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(HgSpace.lg),
        children: [
          // ── Üyeler ──
          _SectionHeader(
            title: 'Üyeler',
            trailing: HgChip(label: '+', color: c.violet, filled: true),
            onTap: _showInviteSheet,
          ),
          const SizedBox(height: HgSpace.sm),
          ..._members.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: HgSpace.xs),
                child: _MemberTile(member: m),
              )),
          const SizedBox(height: HgSpace.xl),

          // ── Paylaşımlı Görevler ──
          Text('Paylaşımlı Görevler',
              style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.sm),
          if (_tasks.isEmpty)
            _PlaceholderTile(text: 'Henüz görev yok', c: c)
          else
            ..._tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: HgSpace.xs),
                  child: _SharedTaskTile(task: t),
                )),
          const SizedBox(height: HgSpace.xl),

          // ── Paylaşımlı CRM ──
          Text('Paylaşımlı CRM',
              style: HgText.heading.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.sm),
          if (_crmEntries.isEmpty)
            _PlaceholderTile(text: 'Henüz müşteri yok', c: c)
          else
            ..._crmEntries.map((e) => Padding(
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
          ?trailing,
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
