// Hanagram — ekip oluşturma / üye davet etme sheet'leri
//
// Modüler sheet bileşenleri — team_screen.dart tarafından kullanılır.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/team_service.dart';

class CreateTeamSheet extends StatefulWidget {
  const CreateTeamSheet({super.key});

  @override
  State<CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<CreateTeamSheet> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.all(HgSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
        ),
        child: StatefulBuilder(builder: (ctx, setSheet) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yeni ekip oluştur',
                  style: HgText.title.copyWith(color: c.text, shadows: null)),
              const SizedBox(height: HgSpace.lg),
              TextField(
                controller: _nameCtrl,
                style: HgText.body.copyWith(color: c.text, shadows: null),
                decoration: InputDecoration(
                  hintText: 'Ekip adı',
                  hintStyle:
                      HgText.body.copyWith(color: c.textMuted, shadows: null),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HgRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setSheet(() {}),
              ),
              const SizedBox(height: HgSpace.xl),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: HgButton(
                    label: 'Kur',
                    color: c.violet,
                    onPressed: _nameCtrl.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(context, _nameCtrl.text.trim()),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class InviteMemberSheet extends StatefulWidget {
  const InviteMemberSheet({super.key});

  @override
  State<InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<InviteMemberSheet> {
  final _queryCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = const [];
  bool _isSearching = false;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _isSearching = true);
    final result = await TeamService.searchUsers(query.trim());
    if (!mounted) return;
    setState(() {
      _results = result;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 450),
        padding: const EdgeInsets.all(HgSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Üye Davet Et',
                style: HgText.title.copyWith(color: c.text, shadows: null)),
            const SizedBox(height: HgSpace.lg),
            TextField(
              controller: _queryCtrl,
              style: HgText.body.copyWith(color: c.text, shadows: null),
              decoration: InputDecoration(
                hintText: 'Kullanıcı adı ara…',
                hintStyle:
                    HgText.body.copyWith(color: c.textMuted, shadows: null),
                filled: true,
                fillColor: c.surfaceAlt,
                prefixIcon: Icon(Icons.search, color: c.textMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HgRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
              autofocus: true,
              onChanged: _search,
            ),
            const SizedBox(height: HgSpace.md),
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_results.isEmpty && _queryCtrl.text.trim().length >= 2)
              Text('Kullanıcı bulunamadı',
                  style: HgText.small.copyWith(color: c.textFaint))
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final u = _results[i];
                    final name = u['full_name'] as String? ?? '';
                    final uname = u['username'] as String? ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Avatar(name: name, size: 36),
                      title: Text(name,
                          style: HgText.body.copyWith(color: c.text)),
                      subtitle: Text('@$uname',
                          style: HgText.caption.copyWith(color: c.textMuted)),
                      trailing: Icon(Icons.add_circle_outline, color: c.violet),
                      onTap: () => Navigator.pop(context, {
                        'userId': u['id'] as String,
                        'name': name,
                      }),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
