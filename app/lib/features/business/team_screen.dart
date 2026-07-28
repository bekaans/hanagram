// Hanagram — ekip yönetimi listesi
//
// Arkadram ekibi oluşturma, üyeleri davet etme, görev/CRM paylaşımı.
// Detay ekranı team_detail_screen.dart, sheet'ler team_sheet.dart'ta.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import 'team_item.dart';
import 'team_sheet.dart';
import 'team_detail_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamItem> _teams = sampleTeams();

  void _createTeam(String name) {
    setState(() {
      _teams.add(TeamItem(
        id: 't${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        members: [const TeamMember(name: 'Sen', role: 'Yönetici')],
      ));
    });
  }

  Future<void> _showCreateSheet() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CreateTeamSheet(),
    );
    if (name != null && mounted) _createTeam(name);
  }

  void _openDetail(TeamItem team) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeamDetailScreen(team: team)),
    ).then((updated) {
      if (updated == true && mounted) setState(() {});
    });
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
        title: Text('Ekip Yönetimi',
            style: HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        backgroundColor: c.violet,
        child: Icon(Icons.group_add, color: c.onBrand),
      ),
      body: _teams.isEmpty
          ? EmptyState(
              icon: Icons.group_outlined,
              title: 'Ekip yok',
              message: 'İlk ekibi oluşturmak için + butonuna dokunun.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  HgSpace.lg, HgSpace.xs, HgSpace.lg, 120),
              itemCount: _teams.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: HgSpace.sm),
                child: _TeamCard(
                  team: _teams[i],
                  onTap: () => _openDetail(_teams[i]),
                ),
              ),
            ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onTap});
  final TeamItem team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return HgCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.violet, c.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(HgRadius.sm),
            ),
            child: Center(
              child: Text(
                team.name.substring(0, 1),
                style: HgText.heading
                    .copyWith(color: c.onBrand, shadows: null),
              ),
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name,
                    style: HgText.bodyStrong
                        .copyWith(color: c.text, shadows: null)),
                const SizedBox(height: HgSpace.xs),
                Text('${team.members.length} üye',
                    style: HgText.caption
                        .copyWith(color: c.textMuted, shadows: null)),
              ],
            ),
          ),
          HgChip(label: 'Sohbet', color: c.violet),
        ],
      ),
    );
  }
}
