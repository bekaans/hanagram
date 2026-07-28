// Hanagram Admin — güncellemeler sekmesi
//
// Versiyon yönetimi: yeni versiyon ekleme, listeleme, düzenleme, silme.
// Supabase app_versions tablosuyla çalışır.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../core/admin_supabase.dart';

class UpdatesTab extends StatefulWidget {
  const UpdatesTab({
    super.key,
    required this.versions,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> versions;
  final VoidCallback onRefresh;

  @override
  State<UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<UpdatesTab> {
  bool _adding = false;

  // Yeni versiyon formu controller'ları
  final _versionCtrl = TextEditingController();
  final _buildCtrl = TextEditingController(text: '1');
  final _urlCtrl = TextEditingController();
  final _changelogCtrl = TextEditingController();
  String _platform = 'android';
  bool _isForce = false;

  @override
  void dispose() {
    _versionCtrl.dispose();
    _buildCtrl.dispose();
    _urlCtrl.dispose();
    _changelogCtrl.dispose();
    super.dispose();
  }

  Future<void> _addVersion() async {
    final version = _versionCtrl.text.trim();
    final build = int.tryParse(_buildCtrl.text.trim()) ?? 1;
    final url = _urlCtrl.text.trim();
    if (version.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Versiyon ve URL gerekli')),
      );
      return;
    }

    try {
      await AdminSupabase.addVersion(
        version: version,
        buildNumber: build,
        platform: _platform,
        downloadUrl: url,
        changelog: _changelogCtrl.text.trim(),
        isForce: _isForce,
      );
      _versionCtrl.clear();
      _buildCtrl.text = '1';
      _urlCtrl.clear();
      _changelogCtrl.clear();
      setState(() => _adding = false);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Versiyon eklendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  Future<void> _toggleForce(String id, bool current) async {
    try {
      await AdminSupabase.updateVersion(id, {'is_force': !current});
      widget.onRefresh();
    } catch (_) {}
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      await AdminSupabase.updateVersion(id, {'is_active': !current});
      widget.onRefresh();
    } catch (_) {}
  }

  Future<void> _deleteVersion(String id) async {
    try {
      await AdminSupabase.deleteVersion(id);
      widget.onRefresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      children: [
        // ─── Başlık + Ekle butonu ───
        Padding(
          padding: const EdgeInsets.all(HgSpace.xl),
          child: Row(
            children: [
              Text('Güncellemeler',
                  style: HgText.display.copyWith(color: c.text)),
              const SizedBox(width: HgSpace.md),
              HgChip(
                  label: '${widget.versions.length}',
                  color: c.violet),
              const Spacer(),
              BrandButton(
                label: 'Yeni versiyon',
                icon: Icons.add,
                onPressed: () => setState(() => _adding = !_adding),
              ),
            ],
          ),
        ),

        // ─── Yeni versiyon formu ───
        if (_adding) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: HgSpace.xl),
            child: HgCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Yeni versiyon ekle',
                      style:
                          HgText.heading.copyWith(color: c.text)),
                  const SizedBox(height: HgSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _field(c, 'Versiyon (1.2.0)',
                            _versionCtrl),
                      ),
                      const SizedBox(width: HgSpace.md),
                      SizedBox(
                        width: 100,
                        child: _field(c, 'Build', _buildCtrl),
                      ),
                      const SizedBox(width: HgSpace.md),
                      _platformSelector(c),
                    ],
                  ),
                  const SizedBox(height: HgSpace.md),
                  _field(c, 'İndirme URL\'si', _urlCtrl),
                  const SizedBox(height: HgSpace.md),
                  _field(c, 'Değişiklik notları', _changelogCtrl,
                      maxLines: 3),
                  const SizedBox(height: HgSpace.md),
                  Row(
                    children: [
                      Switch(
                        value: _isForce,
                        onChanged: (v) =>
                            setState(() => _isForce = v),
                        activeThumbColor: c.danger,
                      ),
                      const SizedBox(width: HgSpace.sm),
                      Text('Zorunlu güncelleme',
                          style: HgText.body
                              .copyWith(color: c.text)),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            setState(() => _adding = false),
                        child: Text('İptal',
                            style: HgText.body
                                .copyWith(color: c.textMuted)),
                      ),
                      const SizedBox(width: HgSpace.md),
                      BrandButton(
                        label: 'Ekle',
                        icon: Icons.check,
                        onPressed: _addVersion,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HgSpace.xl),
        ],

        // ─── Versiyon listesi ───
        Expanded(
          child: widget.versions.isEmpty
              ? const EmptyState(
                  icon: Icons.system_update_outlined,
                  title: 'Henüz versiyon yok',
                  message: 'İlk versiyonu ekleyerek başlayın.',
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: HgSpace.xl),
                  itemCount: widget.versions.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: HgSpace.sm),
                  itemBuilder: (_, i) =>
                      _versionTile(c, widget.versions[i]),
                ),
        ),
      ],
    );
  }

  Widget _versionTile(HgColors c, Map<String, dynamic> v) {
    final version = v['version'] as String? ?? '';
    final build = v['build_number'] ?? '';
    final platform = v['platform'] as String? ?? '';
    final changelog = v['changelog'] as String? ?? '';
    final isForce = v['is_force'] == true;
    final isActive = v['is_active'] == true;
    final createdAt = v['created_at'] as String? ?? '';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Icon(
            isForce ? Icons.warning_amber : Icons.system_update,
            size: 20,
            color: isForce ? c.danger : c.violet,
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('v$version',
                        style: HgText.bodyStrong
                            .copyWith(color: c.text)),
                    const SizedBox(width: HgSpace.sm),
                    Text('build $build',
                        style: HgText.caption
                            .copyWith(color: c.textMuted)),
                  ],
                ),
                if (changelog.isNotEmpty)
                  Text(changelog,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HgText.small
                          .copyWith(color: c.textMuted)),
              ],
            ),
          ),
          HgChip(
            label: platform,
            color: platform == 'android' ? c.success : c.blue,
          ),
          const SizedBox(width: HgSpace.sm),
          GestureDetector(
            onTap: () => _toggleForce(v['id'] as String, isForce),
            child: HgChip(
              label: isForce ? 'ZORUNLU' : 'İsteğe bağlı',
              color: isForce ? c.danger : c.textMuted,
            ),
          ),
          const SizedBox(width: HgSpace.sm),
          GestureDetector(
            onTap: () => _toggleActive(v['id'] as String, isActive),
            child: HgChip(
              label: isActive ? 'Aktif' : 'Pasif',
              color: isActive ? c.success : c.warning,
            ),
          ),
          const SizedBox(width: HgSpace.sm),
          Text(_formatDate(createdAt),
              style: HgText.caption.copyWith(color: c.textFaint)),
          const SizedBox(width: HgSpace.sm),
          IconButton(
            onPressed: () => _confirmDelete(v['id'] as String),
            icon: Icon(Icons.delete_outline,
                size: 18, color: c.danger),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Versiyonu sil'),
        content: const Text('Bu versiyon kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVersion(id);
            },
            child: const Text('Sil',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _platformSelector(HgColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HgSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border),
      ),
      child: DropdownButton<String>(
        value: _platform,
        underline: const SizedBox(),
        dropdownColor: c.surface,
        style: HgText.body.copyWith(color: c.text),
        items: const [
          DropdownMenuItem(value: 'android', child: Text('Android')),
          DropdownMenuItem(value: 'ios', child: Text('iOS')),
          DropdownMenuItem(value: 'macos', child: Text('macOS')),
          DropdownMenuItem(value: 'windows', child: Text('Windows')),
        ],
        onChanged: (v) {
          if (v != null) setState(() => _platform = v);
        },
      ),
    );
  }

  Widget _field(HgColors c, String label, TextEditingController ctrl,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: HgText.body.copyWith(color: c.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: HgText.small.copyWith(color: c.textMuted),
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgRadius.md),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }

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
}
