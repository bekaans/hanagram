// Hanagram — Randevu yönetimi (Supabase)
//
// Seçili günün randevuları + arama ile tüm geçmiş randevuları listeleme.
// Müşteri adına göre arama: tarih, saat, onay/red durumu gösterilir.
import 'package:flutter/material.dart';

import '../../core/task_service.dart';
import 'package:hanagram_design/design.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Appointment> _appointments = [];
  bool _isLoading = true;

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
    try {
      final items = await TaskService.getAppointmentsForDate(_selectedDate);
      if (mounted) {
        setState(() {
          _appointments = items;
          _isLoading = false;
        });
      }
    } on Exception catch (_) {
      // Supabase yoksa örnek randevuları göster
      if (mounted) {
        setState(() {
          _appointments = _sampleAppointments();
          _isLoading = false;
        });
      }
    }
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
        itemBuilder: (context, index) {
          final a = _appointments[index];
          return _appointmentCard(c, a);
        },
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
      'confirmed' => c.success,
      'cancelled' => c.danger,
      _ => c.warning,
    };
    final statusLabel = switch (a.status) {
      'confirmed' => 'Onaylandı ✓',
      'cancelled' => 'İptal ✗',
      _ => 'Bekliyor',
    };
    final statusIcon = switch (a.status) {
      'confirmed' => Icons.check_circle_outline,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.schedule,
    };

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
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
                child: BrandButton(
                  label: _sending ? 'Oluşturuluyor…' : 'Randevu Oluştur',
                  icon: _sending ? null : Icons.check,
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

// ─── Örnek randevu verisi (Supabase yokken) ───

List<Appointment> _sampleAppointments() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    Appointment(
      id: 'sa1', title: 'Elif Yılmaz — Makyaj Kampanyası',
      date: today, startTime: '10:00', createdBy: 'demo',
      description: 'Profesyonel makyaj + fotoğraf çekimi',
      status: 'confirmed', attendeeName: 'Elif Yılmaz',
    ),
    Appointment(
      id: 'sa2', title: 'Dr. Ahmet Kaya — Reklam Görüşmesi',
      date: today, startTime: '14:00', createdBy: 'demo',
      description: 'Instagram reklam kampanyası detayları',
      status: 'pending', attendeeName: 'Dr. Ahmet Kaya',
    ),
    Appointment(
      id: 'sa3', title: 'Studio Nova — Çekim Planlama',
      date: today.add(const Duration(days: 1)),
      startTime: '11:00', createdBy: 'demo',
      description: 'Ekipman ve mekan onayı',
      status: 'pending', attendeeName: 'Studio Nova',
    ),
    Appointment(
      id: 'sa4', title: 'Zeynep Arslan — Kaş Laminasyonu',
      date: today.add(const Duration(days: 2)),
      startTime: '15:30', createdBy: 'demo',
      description: 'Rutin bakım randevusu',
      status: 'confirmed', attendeeName: 'Zeynep Arslan',
    ),
    Appointment(
      id: 'sa5', title: 'Cenk Demir — Saç Bakımı',
      date: today.add(const Duration(days: 3)),
      startTime: '09:00', createdBy: 'demo',
      description: 'Keratin bakım',
      status: 'pending', attendeeName: 'Cenk Demir',
    ),
  ];
}
