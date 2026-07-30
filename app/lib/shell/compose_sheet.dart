// Hanagram — içerik paylaşma sayfası

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import 'package:hanagram_design/design.dart';

class ComposeSheet extends StatefulWidget {
  const ComposeSheet({super.key});

  @override
  State<ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<ComposeSheet> {
  final _ctrl = TextEditingController();
  final _picked = <String>{};

  static const _topics = [
    ('guzellik', 'Güzellik'),
    ('medikal', 'Medikal'),
    ('icerik', 'İçerik'),
    ('reklam', 'Reklam'),
    ('yemek', 'Yemek'),
    ('spor', 'Spor'),
    ('moda', 'Moda'),
    ('teknoloji', 'Teknoloji'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(HgRadius.xl)),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.all(HgSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(HgRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: HgSpace.lg),
            Text('Ne paylaşıyorsun?', style: HgText.title.copyWith(color: c.text)),
            const SizedBox(height: HgSpace.lg),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              style: HgText.body.copyWith(color: c.text),
              decoration: InputDecoration(
                hintText: 'Birkaç cümle yaz…',
                hintStyle: HgText.body.copyWith(color: c.textFaint),
                filled: true,
                fillColor: c.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HgRadius.md),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
            ),
            const SizedBox(height: HgSpace.lg),
            Text('Konu seç', style: HgText.caption.copyWith(color: c.textMuted)),
            const SizedBox(height: HgSpace.sm),
            Wrap(
              spacing: HgSpace.sm,
              runSpacing: HgSpace.sm,
              children: [
                for (final (key, label) in _topics)
                  InkWell(
                    onTap: () => setState(() {
                      _picked.contains(key) ? _picked.remove(key) : _picked.add(key);
                    }),
                    borderRadius: BorderRadius.circular(HgRadius.pill),
                    child: HgChip(
                      label: label,
                      color: _picked.contains(key) ? c.violet : c.textMuted,
                      filled: _picked.contains(key),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: HgSpace.xl),
            BrandButton(
              label: 'Paylaş',
              icon: Icons.send,
              onPressed: _ctrl.text.trim().isEmpty
                  ? null
                  : () {
                      AppScope.of(context)
                          .createPost(_ctrl.text.trim(), _picked.toList());
                      Navigator.of(context).pop();
                    },
            ),
            const SizedBox(height: HgSpace.sm),
          ],
        ),
      ),
    );
  }
}
