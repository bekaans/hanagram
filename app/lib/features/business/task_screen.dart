// Hanagram — İş akışı & görev yönetimi (Supabase)
//
// Görev CRUD + çalışan atama + arama ile tüm görevleri listeleme.
// Çalışan adına göre arama: yaptı/yapmadı, tarih, saat, yeni→eski sıralama.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/task_service.dart';
import '../../core/connection_service.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<TaskItem> _tasks = [];
  List<Map<String, dynamic>> _connections = [];
  bool _loading = true;
  int _tab = 0; // 0=görevler, 1=çalışanlar

  // Arama
  final _searchCtrl = TextEditingController();
  List<TaskItem> _searchResults = [];
  bool _isSearching = false;
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final tasks = await TaskService.getMyTasks(limit: 100);
    final conns = await TaskService.getMyConnections();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _connections = conns;
        _loading = false;
      });
    }
  }

  Future<void> _searchTasks(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    final results = await TaskService.searchTasksByAssignee(query.trim());
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final pending =
        _tasks.where((t) => t.status != TaskStatus.completed).toList();
    final done =
        _tasks.where((t) => t.status == TaskStatus.completed).toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('İş Akışı',
            style:
                HgText.title.copyWith(color: c.text, shadows: null)),
        actions: [
          IconButton(
            icon:
                Icon(CupertinoIcons.person_badge_plus, color: c.violet),
            onPressed: () => _showInviteWorkerSheet(context, c),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: c.violet,
        onPressed: () => _tab == 0
            ? _showAddTaskSheet(context, c)
            : _showInviteWorkerSheet(context, c),
        child: const Icon(CupertinoIcons.plus, color: Colors.white),
      ),
      body: Column(
        children: [
          // ─── Arama Çubuğu ───
          _searchBar(c),
          // ─── Arama modundaysa sonuçları göster ───
          if (_isSearching)
            Expanded(child: _buildSearchResults(c))
          else ...[
            // ─── Normal mod ───
            Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: c.border.withValues(alpha: 0.4),
                        width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                      child:
                          _tabBtn(c, 'Görevler', pending.length, 0)),
                  Expanded(
                      child: _tabBtn(
                          c, 'Çalışanlar', _connections.length, 1)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tab == 0
                      ? _buildTaskList(c, pending, done)
                      : _buildWorkerList(c),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchBar(HgColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          HgSpace.lg, HgSpace.md, HgSpace.lg, 0),
      child: TextField(
        controller: _searchCtrl,
        style: HgText.body.copyWith(color: c.text),
        onChanged: (v) {
          final query = v.trim();
          if (query.isEmpty) {
            setState(() {
              _isSearching = false;
              _searchResults = [];
            });
            _loadData();
            return;
          }
          setState(() => _isSearching = true);
          _searchTasks(query);
        },
        decoration: InputDecoration(
          hintText: 'Çalışan adı ile görev ara…',
          hintStyle: HgText.body.copyWith(color: c.textFaint),
          filled: true,
          fillColor: c.surfaceAlt,
          prefixIcon: Icon(Icons.search, color: c.textMuted),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.close, color: c.textMuted),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                    });
                    _loadData();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HgRadius.md),
            borderSide: BorderSide(color: c.border),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: HgSpace.md),
        ),
      ),
    );
  }

  // ─── Arama Sonuçları (çalışana ait tüm görevler) ───

  Widget _buildSearchResults(HgColors c) {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.search_off,
          title: 'Sonuç bulunamadı',
          message: 'Farklı bir isim deneyin.',
        ),
      );
    }

    // Grupla: tamamlananlar ve yapılmayanlar
    final completed =
        _searchResults.where((t) => t.status == TaskStatus.completed).toList();
    final pending =
        _searchResults.where((t) => t.status != TaskStatus.completed).toList();

    return RefreshIndicator(
      onRefresh: () async => _searchTasks(_searchCtrl.text),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            HgSpace.lg, HgSpace.md, HgSpace.lg, 96),
        children: [
          // Sonuç sayısı
          Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: c.textMuted),
              const SizedBox(width: HgSpace.sm),
              Text('${_searchResults.length} görev bulundu',
                  style: HgText.caption
                      .copyWith(color: c.textMuted)),
            ],
          ),
          const SizedBox(height: HgSpace.md),
          // Yapılmayanlar
          if (pending.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.radio_button_unchecked,
                    size: 16, color: c.warning),
                const SizedBox(width: HgSpace.sm),
                Text('Yapılmayanlar (${pending.length})',
                    style: HgText.heading
                        .copyWith(color: c.text)),
              ],
            ),
            const SizedBox(height: HgSpace.sm),
            for (final t in pending) _searchTaskCard(c, t),
            const SizedBox(height: HgSpace.xl),
          ],
          // Tamamlananlar
          if (completed.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 16, color: c.success),
                const SizedBox(width: HgSpace.sm),
                Text('Tamamlananlar (${completed.length})',
                    style: HgText.heading
                        .copyWith(color: c.textMuted)),
              ],
            ),
            const SizedBox(height: HgSpace.sm),
            for (final t in completed) _searchTaskCard(c, t),
          ],
        ],
      ),
    );
  }

  Widget _searchTaskCard(HgColors c, TaskItem task) {
    final isDone = task.status == TaskStatus.completed;
    final statusColor = isDone ? c.success : c.warning;
    final statusLabel = switch (task.status) {
      TaskStatus.completed => 'Tamamlandı ✓',
      TaskStatus.rejected => 'Reddedildi',
      TaskStatus.accepted => 'Kabul edildi',
      TaskStatus.inProgress => 'Devam ediyor',
      _ => 'Bekliyor',
    };

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          // Durum ikonu
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(HgRadius.sm),
            ),
            child: Icon(
              isDone ? Icons.check : Icons.radio_button_unchecked,
              size: 18,
              color: statusColor,
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: HgText.bodyStrong.copyWith(
                      color: c.text,
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : null,
                    )),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 12, color: c.textFaint),
                    const SizedBox(width: 4),
                    Text(_formatDateTime(task.createdAt),
                        style: HgText.caption
                            .copyWith(color: c.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (task.creatorName.isNotEmpty) ...[
                      Text('Oluşturan: ${task.creatorName}',
                          style: HgText.small
                              .copyWith(color: c.textFaint)),
                      const SizedBox(width: HgSpace.sm),
                    ],
                    if (task.assigneeName.isNotEmpty)
                      Text('Atanan: ${task.assigneeName}',
                          style: HgText.small
                              .copyWith(color: c.textFaint)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              _priorityChip(c, task.priority),
              const SizedBox(height: HgSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      statusColor.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(HgRadius.pill),
                ),
                child: Text(statusLabel,
                    style: HgText.small
                        .copyWith(color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(HgColors c, String label, int count, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: HgSpace.md),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? c.violet : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: HgText.bodyStrong.copyWith(
                    color:
                        active ? c.violet : c.textMuted)),
            const SizedBox(width: HgSpace.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? c.violet.withValues(alpha: 0.15)
                    : c.surfaceAlt,
                borderRadius:
                    BorderRadius.circular(HgRadius.pill),
              ),
              child: Text('$count',
                  style: HgText.caption.copyWith(
                      color:
                          active ? c.violet : c.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList(
      HgColors c, List<TaskItem> pending, List<TaskItem> done) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(HgSpace.lg),
        children: [
          Row(
            children: [
              Expanded(
                  child: _miniStat(
                      c, 'Devam', '${pending.length}', c.violet)),
              const SizedBox(width: HgSpace.sm),
              Expanded(
                  child: _miniStat(
                      c, 'Tamam', '${done.length}', c.success)),
              const SizedBox(width: HgSpace.sm),
              Expanded(
                  child: _miniStat(
                      c, 'Toplam', '${_tasks.length}', c.blue)),
            ],
          ),
          const SizedBox(height: HgSpace.xl),
          if (pending.isNotEmpty) ...[
            Text('Devam Eden Görevler',
                style: HgText.heading
                    .copyWith(color: c.text, shadows: null)),
            const SizedBox(height: HgSpace.md),
            for (final task in pending) _taskCard(c, task),
            const SizedBox(height: HgSpace.xl),
          ],
          if (done.isNotEmpty) ...[
            Text('Tamamlanan',
                style: HgText.heading
                    .copyWith(color: c.textMuted, shadows: null)),
            const SizedBox(height: HgSpace.md),
            for (final task in done) _taskCard(c, task),
          ],
        ],
      ),
    );
  }

  Widget _taskCard(HgColors c, TaskItem task) {
    final isDone = task.status == TaskStatus.completed;
    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          GestureDetector(
            onTap: isDone
                ? null
                : () async {
                    await TaskService.updateTaskStatus(
                        task.id, TaskStatus.completed);
                    _loadData();
                  },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? c.success : c.textMuted,
                  width: 2,
                ),
                color: isDone
                    ? c.success.withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
              child: isDone
                  ? Icon(Icons.check, size: 14, color: c.success)
                  : null,
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: HgText.bodyStrong.copyWith(
                      color: c.text,
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : null,
                    )),
                if (task.assigneeName.isNotEmpty)
                  Text('Atanan: ${task.assigneeName}',
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
              ],
            ),
          ),
          _priorityChip(c, task.priority),
          if (task.dueDate != null) ...[
            const SizedBox(width: HgSpace.sm),
            Text(_formatDate(task.dueDate!),
                style: HgText.caption
                    .copyWith(color: c.textFaint)),
          ],
        ],
      ),
    );
  }

  Widget _priorityChip(HgColors c, TaskPriority p) {
    final (label, color) = switch (p) {
      TaskPriority.urgent => ('Acil', c.danger),
      TaskPriority.high => ('Yüksek', c.coral),
      TaskPriority.medium => ('Normal', c.blue),
      TaskPriority.low => ('Düşük', c.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius:
            BorderRadius.circular(HgRadius.pill),
      ),
      child: Text(label,
          style: HgText.caption.copyWith(color: color)),
    );
  }

  Widget _buildWorkerList(HgColors c) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _connections.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.people_outline,
                title: 'Henüz çalışan yok',
                message:
                    'Bağlantı ekranından arkadaş/çalışan ekleyin.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(HgSpace.lg),
              itemCount: _connections.length,
              itemBuilder: (_, i) {
                final conn = _connections[i];
                final connected =
                    (conn['connected'] as Map?)
                            ?.cast<String, dynamic>() ??
                        {};
                final name =
                    connected['full_name'] as String? ?? '';
                final username =
                    connected['username'] as String? ?? '';
                final role =
                    conn['role'] as String? ?? 'friend';

                return HgCard(
                  padding:
                      const EdgeInsets.all(HgSpace.md),
                  child: Row(
                    children: [
                      Avatar(name: name, size: 40),
                      const SizedBox(width: HgSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: HgText.bodyStrong
                                    .copyWith(
                                        color: c.text)),
                            Text('@$username',
                                style: HgText.caption
                                    .copyWith(
                                        color:
                                            c.textMuted)),
                          ],
                        ),
                      ),
                      HgChip(
                        label: switch (role) {
                          'employee' => 'Çalışan',
                          'employer' => 'İşveren',
                          _ => 'Arkadaş',
                        },
                        color: switch (role) {
                          'employee' => c.blue,
                          'employer' => c.coral,
                          _ => c.violet,
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _miniStat(
      HgColors c, String label, String value, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: HgSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(value,
              style:
                  HgText.title.copyWith(color: color)),
          Text(label,
              style: HgText.caption
                  .copyWith(color: c.textMuted)),
        ],
      ),
    );
  }

  // ─── Yeni Görev Oluşturma ───

  void _showAddTaskSheet(BuildContext context, HgColors c) {
    final titleCtrl = TextEditingController();
    String? selectedUserId;
    String selectedPriority = 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          padding: const EdgeInsets.all(HgSpace.xl),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(HgRadius.xl)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius:
                            BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: HgSpace.lg),
                Text('Yeni Görev',
                    style: HgText.title.copyWith(
                        color: c.text, shadows: null)),
                const SizedBox(height: HgSpace.lg),
                TextField(
                  controller: titleCtrl,
                  style: HgText.body
                      .copyWith(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Görev açıklaması',
                    hintStyle: HgText.body
                        .copyWith(color: c.textFaint),
                    filled: true,
                    fillColor: c.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          HgRadius.md),
                      borderSide:
                          BorderSide(color: c.border),
                    ),
                  ),
                ),
                const SizedBox(height: HgSpace.md),
                Text('Ata',
                    style: HgText.caption.copyWith(
                        color: c.textMuted,
                        shadows: null)),
                const SizedBox(height: HgSpace.sm),
                if (_connections.isEmpty)
                  Text('Önce bağlantı ekleyin',
                      style: HgText.small
                          .copyWith(color: c.textFaint))
                else
                  Wrap(
                    spacing: HgSpace.sm,
                    children: _connections.map((conn) {
                      final u =
                          (conn['connected'] as Map?)
                                  ?.cast<String,
                                      dynamic>() ??
                              {};
                      final name =
                          u['full_name'] as String? ??
                              '';
                      final uid =
                          u['id'] as String? ?? '';
                      final selected =
                          selectedUserId == uid;
                      return GestureDetector(
                        onTap: () => setSheetState(
                            () =>
                                selectedUserId = uid),
                        child: HgChip(
                          label: name,
                          color: selected
                              ? c.violet
                              : c.textMuted,
                          filled: selected,
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: HgSpace.md),
                Text('Öncelik',
                    style: HgText.caption.copyWith(
                        color: c.textMuted,
                        shadows: null)),
                const SizedBox(height: HgSpace.sm),
                Row(
                  children: [
                    _priorityOption(c, setSheetState,
                        'low', 'Düşük',
                        selectedPriority, c.textMuted),
                    _priorityOption(c, setSheetState,
                        'medium', 'Normal',
                        selectedPriority, c.blue),
                    _priorityOption(c, setSheetState,
                        'high', 'Yüksek',
                        selectedPriority, c.coral),
                    _priorityOption(c, setSheetState,
                        'urgent', 'Acil',
                        selectedPriority, c.danger),
                  ],
                ),
                const SizedBox(height: HgSpace.xl),
                BrandButton(
                  label: 'Görev Oluştur',
                  onPressed:
                      titleCtrl.text.trim().isEmpty
                          ? null
                          : () async {
                              await TaskService.createTask(
                                title: titleCtrl.text.trim(),
                                assignedTo: selectedUserId,
                                priority: TaskPriority
                                    .values
                                    .firstWhere((e) =>
                                        e.name ==
                                        selectedPriority),
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              _loadData();
                            },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _priorityOption(
    HgColors c,
    StateSetter setSheetState,
    String value,
    String label,
    String selected,
    Color color,
  ) {
    final isSelected = selected == value;
    return Padding(
      padding:
          const EdgeInsets.only(right: HgSpace.sm),
      child: GestureDetector(
        onTap: () =>
            setSheetState(() => selected = value),
        child: HgChip(
          label: label,
          color: isSelected ? color : c.textMuted,
          filled: isSelected,
        ),
      ),
    );
  }

  // ─── Çalışan Davet ───

  void _showInviteWorkerSheet(
      BuildContext context, HgColors c) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          padding: const EdgeInsets.all(HgSpace.xl),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(HgRadius.xl)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius:
                            BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: HgSpace.lg),
                Text('Kişi Ekle',
                    style: HgText.title.copyWith(
                        color: c.text, shadows: null)),
                const SizedBox(height: HgSpace.sm),
                Text('Kullanıcı adı ile arama yapın',
                    style: HgText.caption.copyWith(
                        color: c.textMuted,
                        shadows: null)),
                const SizedBox(height: HgSpace.lg),
                TextField(
                  controller: searchCtrl,
                  style: HgText.body
                      .copyWith(color: c.text),
                  onChanged: (v) async {
                    if (v.trim().length < 2) {
                      setSheetState(
                          () => searchResults = []);
                      return;
                    }
                    final results =
                        await ConnectionService
                            .searchUsers(v.trim());
                    setSheetState(
                        () => searchResults = results);
                  },
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı adı ara…',
                    hintStyle: HgText.body
                        .copyWith(color: c.textFaint),
                    filled: true,
                    fillColor: c.surfaceAlt,
                    prefixIcon: Icon(Icons.search,
                        color: c.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          HgRadius.md),
                      borderSide:
                          BorderSide(color: c.border),
                    ),
                  ),
                ),
                const SizedBox(height: HgSpace.md),
                if (searchResults.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (_, i) {
                        final u = searchResults[i];
                        final name =
                            u['full_name'] as String? ??
                                '';
                        final uname =
                            u['username'] as String? ??
                                '';
                        final uid =
                            u['auth_id'] as String? ??
                                '';
                        return ListTile(
                          leading:
                              Avatar(name: name, size: 36),
                          title: Text(name,
                              style: HgText.body.copyWith(
                                  color: c.text)),
                          subtitle: Text('@$uname',
                              style: HgText.caption
                                  .copyWith(
                                      color: c.textMuted)),
                          trailing: Icon(
                              Icons.person_add,
                              color: c.violet),
                          onTap: () async {
                            await ConnectionService
                                .sendRequest(uid);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx)
                                  .showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Bağlantı isteği gönderildi!')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}';
  }

  static String _formatDateTime(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
