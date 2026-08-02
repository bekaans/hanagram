// Hanagram — Randevu yönetimi (Supabase)
//
// Seçili günün randevuları + arama ile tüm geçmiş randevuları listeleme.
// Müşteri adına göre arama: tarih, saat, onay/red durumu gösterilir.
import 'package:flutter/material.dart';

import '../../core/appointment_reminder.dart';
import '../../core/task_service.dart';
import '../../core/crm_service.dart';
import '../../core/service_catalog.dart';
import 'package:hanagram_design/design.dart';
import '../settings/settings_provider.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  List<BusinessService> _services = const [];

  // Arama
  final _searchCtrl = TextEditingController();
  List<Appointment> _searchResults = [];
  bool _isSearching = false;
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      TaskService.getAppointmentsForDate(_selectedDate),
      ServiceCatalog.getMyServices(),
    ]);
    if (!mounted) return;
    setState(() {
      _appointments = results[0] as List<Appointment>;
      _services = results[1] as List<BusinessService>;
      _isLoading = false;
    });
  }

  Future<void> _searchAppointments(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results = await TaskService.searchAppointments(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searchLoading = false;
        });
      }
    }
  }

  /// Randevuyu tamamlar VE aynı anda satış kaydı oluşturur.
  /// Tutar kullanıcıdan sorulur (randevuda fiyat bilgisi tutulmuyor).
  Future<void> _completeAsSale(Appointment a) async {
    final amountCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = HgTheme.of(ctx);
        return AlertDialog(
          title: const Text('Satış olarak ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.title,
                style: HgText.caption.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: HgSpace.md),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tutar (₺)',
                  hintText: '0,00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      amountCtrl.dispose();
      return;
    }

    final parsed =
        double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final kurus = (parsed * 100).round();
    amountCtrl.dispose();

    if (!mounted) return;
    if (kurus <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir tutar gir.')),
      );
      return;
    }

    final saleId = await CrmService.createSale(
      items: [
        {'name': a.title, 'price': kurus, 'qty': 1},
      ],
      customerName: a.attendeeName,
      note: 'Randevudan oluşturuldu',
    );
    if (!mounted) return;

    if (saleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış kaydedilemedi, tekrar dene.')),
      );
      return;
    }

    // Satış kaydedildikten SONRA randevuyu tamamla
    await _handleStatusChange(a.id, 'completed');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Satış kaydedildi ve randevu tamamlandı.')),
    );
  }

  Future<void> _handleStatusChange(String id, String action) async {
    SettingsScope.of(context).hapticTap();
    final ok = switch (action) {
      'confirmed' => await AppointmentReminder.confirmAppointment(id),
      'completed' => await AppointmentReminder.completeAppointment(id),
      _ => await AppointmentReminder.cancelAppointment(id),
    };
    if (!mounted) return;
    if (ok) {
      if (_isSearching) {
        await _searchAppointments(_searchCtrl.text);
      } else {
        await _loadAppointments();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Güncellenemedi, tekrar deneyin.')),
      );
    }
  }

  void _openAddSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppointmentAddSheet(
        selectedDate: _selectedDate,
        onAdded: _loadAppointments,
      ),
    );
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
        title: Text('Randevular',
            style:
                HgText.title.copyWith(color: c.text, shadows: null)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: c.violet,
        child: Icon(Icons.add, color: c.onBrand),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Arama Çubuğu ───
            _searchBar(c),
            // ─── Arama modundaysa sonuçları göster ───
            if (_isSearching) ...[
              Expanded(child: _buildSearchResults(c)),
            ] else ...[
              // ─── Normal mod: gün seçici + o günün randevuları ───
              _buildDayPicker(c),
              const SizedBox(height: HgSpace.md),
              Expanded(child: _buildContent(c)),
            ],
          ],
        ),
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
            _loadAppointments();
            return;
          }
          setState(() => _isSearching = true);
          _searchAppointments(query);
        },
        decoration: InputDecoration(
          hintText: 'Müşteri veya randevu ara…',
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
                    _loadAppointments();
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

  Widget _buildDayPicker(HgColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: c.text),
            onPressed: () {
              setState(() {
                _selectedDate =
                    _selectedDate.subtract(const Duration(days: 1));
              });
              _loadAppointments();
            },
          ),
          const Spacer(),
          Text(
            _formatDate(_selectedDate),
            style: HgText.heading.copyWith(color: c.text),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.chevron_right, color: c.text),
            onPressed: () {
              setState(() {
                _selectedDate =
                    _selectedDate.add(const Duration(days: 1));
              });
              _loadAppointments();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Hiç hizmet tanımlanmamışsa gruplama anlamsız — düz liste göster.
    if (_services.isEmpty) {
      if (_appointments.isEmpty) {
        return const EmptyState(
          icon: Icons.event_busy,
          title: 'Bu gün için randevu yok',
          message: 'Yeni randevu eklemek için + butonuna dokunun.',
        );
      }
      return RefreshIndicator(
        onRefresh: _loadAppointments,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              HgSpace.lg, HgSpace.xs, HgSpace.lg, 96),
          itemCount: _appointments.length,
          itemBuilder: (context, index) =>
              _appointmentCard(c, _appointments[index]),
        ),
      );
    }

    // Randevuları hizmete göre grupla
    final byService = <String, List<Appointment>>{};
    final unassigned = <Appointment>[];
    for (final a in _appointments) {
      final sid = a.serviceId;
      if (sid == null || sid.isEmpty) {
        unassigned.add(a);
      } else {
        byService.putIfAbsent(sid, () => []).add(a);
      }
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            HgSpace.lg, HgSpace.xs, HgSpace.lg, 96),
        children: [
          for (final s in _services) ...[
            _serviceHeader(c, s.name, byService[s.id]?.length ?? 0),
            if ((byService[s.id] ?? const []).isEmpty)
              Padding(
                padding: const EdgeInsets.only(
                    left: HgSpace.sm, bottom: HgSpace.md),
                child: Text(
                  'Bu gün randevu yok',
                  style: HgText.caption
                      .copyWith(color: c.textFaint, shadows: null),
                ),
              )
            else
              for (final a in byService[s.id]!) _appointmentCard(c, a),
          ],
          if (unassigned.isNotEmpty) ...[
            _serviceHeader(c, 'Hizmet belirtilmemiş', unassigned.length),
            for (final a in unassigned) _appointmentCard(c, a),
          ],
        ],
      ),
    );
  }

  /// Hizmet grubu başlığı — ad + o günkü randevu sayısı.
  Widget _serviceHeader(HgColors c, String name, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: HgSpace.md, bottom: HgSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: HgText.heading.copyWith(color: c.text, shadows: null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: HgSpace.sm, vertical: 2),
              decoration: BoxDecoration(
                color: c.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(HgRadius.pill),
              ),
              child: Text(
                '$count',
                style: HgText.caption.copyWith(color: c.violet, shadows: null),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Arama Sonuçları ───

  Widget _buildSearchResults(HgColors c) {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Sonuç bulunamadı',
        message: 'Farklı bir arama deneyin.',
      );
    }

    // Tarihe göre grupla (en yeniden en eskiye)
    final grouped = <String, List<Appointment>>{};
    for (final a in _searchResults) {
      final key = '${a.date.year}-${a.date.month.toString().padLeft(2, '0')}-${a.date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(a);
    }

    return RefreshIndicator(
      onRefresh: () async => _searchAppointments(_searchCtrl.text),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            HgSpace.lg, HgSpace.md, HgSpace.lg, 96),
        children: [
          // Sonuç sayısı
          Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: c.textMuted),
              const SizedBox(width: HgSpace.sm),
              Text('${_searchResults.length} randevu bulundu',
                  style: HgText.caption
                      .copyWith(color: c.textMuted)),
            ],
          ),
          const SizedBox(height: HgSpace.md),
          for (final entry in grouped.entries) ...[
            // Tarih başlığı
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: HgSpace.md, vertical: HgSpace.sm),
              decoration: BoxDecoration(
                color: c.violet.withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(HgRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: c.violet),
                  const SizedBox(width: HgSpace.sm),
                  Text(_formatDateFull(entry.value.first.date),
                      style: HgText.bodyStrong
                          .copyWith(color: c.violet)),
                ],
              ),
            ),
            const SizedBox(height: HgSpace.sm),
            for (final a in entry.value)
              _appointmentCard(c, a),
            const SizedBox(height: HgSpace.md),
          ],
        ],
      ),
    );
  }

  Widget _appointmentCard(HgColors c, Appointment a) {
    final statusColor = switch (a.status) {
      'confirmed' => c.blue,
      'completed' => c.success,
      'cancelled' => c.danger,
      _ => c.warning,
    };
    final statusLabel = switch (a.status) {
      'confirmed' => 'Onaylandı ✓',
      'completed' => 'Tamamlandı',
      'cancelled' => 'İptal ✗',
      _ => 'Bekliyor',
    };
    final statusIcon = switch (a.status) {
      'confirmed' => Icons.check_circle_outline,
      'completed' => Icons.task_alt,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.schedule,
    };
    final canAct = a.status == 'pending' || a.status == 'confirmed';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: HgSpace.md),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HgRadius.sm),
                ),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: HgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: HgText.bodyStrong
                            .copyWith(color: c.text)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: c.textFaint),
                        const SizedBox(width: 4),
                        Text('${a.date.day.toString().padLeft(2, '0')}.'
                            '${a.date.month.toString().padLeft(2, '0')}.'
                            '${a.date.year}',
                            style: HgText.caption
                                .copyWith(color: c.textMuted)),
                        const SizedBox(width: HgSpace.md),
                        Icon(Icons.access_time,
                            size: 12, color: c.textFaint),
                        const SizedBox(width: 4),
                        Text(a.startTime,
                            style: HgText.caption
                                .copyWith(color: c.textMuted)),
                      ],
                    ),
                    if (a.attendeeName.isNotEmpty)
                      Text('Katılımcı: ${a.attendeeName}',
                          style: HgText.caption
                              .copyWith(color: c.textFaint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(HgRadius.pill),
                ),
                child: Text(statusLabel,
                    style: HgText.small
                        .copyWith(color: statusColor)),
              ),
            ],
          ),
          // Ön görüşme rozeti
          if (a.isConsultation) ...[
            const SizedBox(height: HgSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: HgSpace.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: c.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HgRadius.sm),
                ),
                child: Text(
                  'Ön görüşme',
                  style: HgText.caption
                      .copyWith(color: c.blue, shadows: null),
                ),
              ),
            ),
          ],

          // Müşteri telefonu
          if (a.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 13, color: c.textFaint),
                const SizedBox(width: 4),
                Text(
                  a.customerPhone,
                  style: HgText.caption
                      .copyWith(color: c.textMuted, shadows: null),
                ),
              ],
            ),
          ],

          // Randevu notu
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(HgSpace.sm),
              decoration: BoxDecoration(
                color: c.surfaceAlt.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(HgRadius.sm),
              ),
              child: Text(
                a.note,
                style: HgText.caption
                    .copyWith(color: c.textMuted, shadows: null),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          if (canAct) ...[
            const SizedBox(height: HgSpace.sm),
            Row(
              children: [
                if (a.status == 'pending') ...[
                  _StatusButton(
                    label: 'Onayla',
                    color: c.success,
                    onTap: () => _handleStatusChange(a.id, 'confirmed'),
                  ),
                  const SizedBox(width: HgSpace.sm),
                  _StatusButton(
                    label: 'Reddet',
                    color: c.danger,
                    onTap: () => _handleStatusChange(a.id, 'cancelled'),
                  ),
                ] else if (a.status == 'confirmed') ...[
                  _StatusButton(
                    label: 'Satış olarak ekle',
                    color: c.violet,
                    onTap: () => _completeAsSale(a),
                  ),
                  const SizedBox(width: HgSpace.sm),
                  _StatusButton(
                    label: 'Tamamlandı',
                    color: c.success,
                    onTap: () => _handleStatusChange(a.id, 'completed'),
                  ),
                  const SizedBox(width: HgSpace.sm),
                  _StatusButton(
                    label: 'İptal',
                    color: c.danger,
                    onTap: () => _handleStatusChange(a.id, 'cancelled'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    const days = [
      '', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  static String _formatDateFull(DateTime d) {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    const days = [
      '', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }
}

// ─── Randevu Ekleme Sheet'i ───

class _AppointmentAddSheet extends StatefulWidget {
  const _AppointmentAddSheet({
    required this.selectedDate,
    required this.onAdded,
  });

  final DateTime selectedDate;
  final VoidCallback onAdded;

  @override
  State<_AppointmentAddSheet> createState() => _AppointmentAddSheetState();
}

class _AppointmentAddSheetState extends State<_AppointmentAddSheet> {
  final _titleCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '09:00');
  final _customerCtrl = TextEditingController();
  String? _attendeeId;
  List<Map<String, dynamic>> _connections = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final conns = await TaskService.getMyConnections();
    if (mounted) setState(() => _connections = conns);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _timeCtrl.dispose();
    _customerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.all(HgSpace.xl),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(HgRadius.xl)),
        ),
        child: SingleChildScrollView(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: HgSpace.lg),
              Text('Yeni Randevu',
                  style: HgText.title
                      .copyWith(color: c.text, shadows: null)),
              const SizedBox(height: HgSpace.lg),
              TextField(
                controller: _titleCtrl,
                style: HgText.body.copyWith(color: c.text),
                decoration: _inputDec(c, 'Randevu başlığı'),
              ),
              const SizedBox(height: HgSpace.md),
              TextField(
                controller: _timeCtrl,
                style: HgText.body.copyWith(color: c.text),
                decoration: _inputDec(c, 'Saat (09:00)'),
              ),
              const SizedBox(height: HgSpace.md),
              TextField(
                controller: _customerCtrl,
                style: HgText.body.copyWith(color: c.text),
                decoration: _inputDec(c, 'Müşteri adı (isteğe bağlı)'),
              ),
              const SizedBox(height: HgSpace.md),
              Text('Katılımcı (isteğe bağlı)',
                  style: HgText.caption
                      .copyWith(color: c.textMuted)),
              const SizedBox(height: HgSpace.sm),
              if (_connections.isNotEmpty)
                Wrap(
                  spacing: HgSpace.sm,
                  children: _connections.map((conn) {
                    final u =
                        (conn['connected'] as Map?)?.cast<String, dynamic>() ?? {};
                    final name = u['full_name'] as String? ?? '';
                    final uid = u['id'] as String? ?? '';
                    final selected = _attendeeId == uid;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _attendeeId = uid),
                      child: HgChip(
                        label: name,
                        color: selected ? c.violet : c.textMuted,
                        filled: selected,
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: HgSpace.xl),
              SizedBox(
                width: double.infinity,
                child: HgButton(
                  label: _sending ? 'Oluşturuluyor…' : 'Randevu Oluştur',
                  loading: _sending,
                  onPressed: _sending || _titleCtrl.text.trim().isEmpty
                      ? null
                      : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _sending = true);

    String customerName = _customerCtrl.text.trim();
    if (customerName.isEmpty && _attendeeId != null) {
      for (final conn in _connections) {
        final u =
            (conn['connected'] as Map?)?.cast<String, dynamic>() ?? {};
        if (u['id'] == _attendeeId) {
          customerName = u['full_name'] as String? ?? '';
          break;
        }
      }
    }

    final result = await TaskService.createAppointment(
      title: _titleCtrl.text.trim(),
      date: widget.selectedDate,
      startTime: _timeCtrl.text.trim(),
      attendeeId: _attendeeId,
      customerName: customerName,
    );

    if (mounted) {
      setState(() => _sending = false);
      if (result != null) {
        widget.onAdded();
        Navigator.pop(context);
      }
    }
  }

  InputDecoration _inputDec(HgColors c, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: HgText.body.copyWith(color: c.textFaint),
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HgRadius.md),
        borderSide: BorderSide(color: c.border),
      ),
    );
  }
}

// ─── Durum değiştirme butonu (onayla/reddet/tamamla/iptal) ───

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(HgRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(HgRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: HgText.caption.copyWith(color: color)),
        ),
      ),
    );
  }
}
