// Hanagram — ekip oluşturma / üye davet etme sheet'leri
//
// Modüler sheet bileşenleri — team_screen.dart tarafından kullanılır.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';

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
        constraints: const BoxConstraints(maxHeight: 350),
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
              Text('Üye Davet Et',
                  style: HgText.title.copyWith(color: c.text, shadows: null)),
              const SizedBox(height: HgSpace.lg),
              TextField(
                controller: _nameCtrl,
                style: HgText.body.copyWith(color: c.text, shadows: null),
                decoration: InputDecoration(
                  hintText: 'Üye adı',
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
                    label: 'Davet Et',
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
