// Hanagram — İşletme ön görüşme randevusu alma ekranı.
// Hizmet → gün → saat → telefon → talep gönder akışını yönetir.

import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/service_catalog.dart';
import '../../core/appointment_slots.dart';
import '../../core/booking_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  final String businessId;
  final String businessName;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<BusinessService> _services = const [];
  BusinessService? _selectedService;
  DateTime _selectedDate = DateTime.now();
  List<AppointmentSlot> _slots = const [];
  AppointmentSlot? _selectedSlot;
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loadingServices = true;
  bool _loadingSlots = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final services = await ServiceCatalog.getServices(widget.businessId);
    if (!mounted) return;
    setState(() {
      _services = services;
      _loadingServices = false;
    });
  }

  Future<void> _loadSlots() async {
    final svc = _selectedService;
    if (svc == null) return;
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });
    final slots = await AppointmentSlots.freeSlots(
      businessId: widget.businessId,
      date: _selectedDate,
      durationMinutes: svc.durationMinutes,
    );
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _loadingSlots = false;
    });
  }

  Future<void> _submit() async {
    final svc = _selectedService;
    final slot = _selectedSlot;
    if (svc == null || slot == null) return;

    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geçerli bir telefon numarası gir (10 hane).'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final already = await BookingService.hasPendingRequest(widget.businessId);
    if (!mounted) return;
    if (already) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu işletmede bekleyen bir randevu talebin zaten var.',
          ),
        ),
      );
      return;
    }

    final id = await BookingService.requestConsultation(
      businessId: widget.businessId,
      businessName: widget.businessName,
      serviceId: svc.id,
      serviceName: svc.name,
      slotStart: slot.start,
      durationMinutes: svc.durationMinutes,
      phone: _phoneCtrl.text,
      note: _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Talep gönderilemedi, tekrar dene.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Randevu talebin gönderildi. İşletme onaylayınca bildirim alacaksın.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    const gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('Randevu Al', style: HgText.title.copyWith(color: c.text)),
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
      ),
      body: ListView(
        padding: EdgeInsets.all(HgSpace.lg),
        children: [
          // 1. Bilgi kutusu
          HgCard(
            child: Text(
              'Şu an sadece ön görüşme randevusu alabilirsin. '
              'İşlem randevun ön görüşmeden sonra planlanacak.',
              style: HgText.caption.copyWith(color: c.textMuted),
            ),
          ),
          SizedBox(height: HgSpace.lg),

          // 2. Hizmet seçimi
          Text('Hizmet', style: HgText.heading.copyWith(color: c.text)),
          SizedBox(height: HgSpace.sm),
          if (_loadingServices)
            const Center(child: CircularProgressIndicator())
          else if (_services.isEmpty)
            EmptyState(
              icon: Icons.info_outline,
              title: 'Hizmet bulunamadı',
              message: 'Bu işletme henüz hizmet eklememiş.',
            )
          else
            ..._services.map(
              (s) => Padding(
                padding: EdgeInsets.only(bottom: HgSpace.sm),
                child: HgCard(
                  onTap: () {
                    setState(() => _selectedService = s);
                    _loadSlots();
                  },
                  accent: _selectedService?.id == s.id ? c.violet : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: HgText.bodyStrong.copyWith(color: c.text),
                      ),
                      SizedBox(height: HgSpace.xs),
                      Text(
                        '${s.priceLabel} · ${s.durationMinutes} dk',
                        style: HgText.caption.copyWith(color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Gün seçimi — sadece hizmet seçildiyse
          if (_selectedService != null) ...[
            SizedBox(height: HgSpace.lg),
            Text('Gün', style: HgText.heading.copyWith(color: c.text)),
            SizedBox(height: HgSpace.sm),
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                itemBuilder: (context, i) {
                  final d = DateTime.now().add(Duration(days: i));
                  final isSelected = DateUtils.isSameDay(d, _selectedDate);
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = d);
                      _loadSlots();
                    },
                    child: Container(
                      width: 56,
                      margin: EdgeInsets.only(right: HgSpace.sm),
                      decoration: BoxDecoration(
                        color: isSelected ? c.violet : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(HgRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            gunler[d.weekday - 1],
                            style: HgText.caption.copyWith(
                              color: isSelected ? c.onBrand : c.textMuted,
                            ),
                          ),
                          SizedBox(height: HgSpace.xs),
                          Text(
                            '${d.day}',
                            style: HgText.bodyStrong.copyWith(
                              color: isSelected ? c.onBrand : c.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. Saat seçimi
            SizedBox(height: HgSpace.lg),
            Text('Saat', style: HgText.heading.copyWith(color: c.text)),
            SizedBox(height: HgSpace.sm),
            if (_loadingSlots)
              const Center(child: CircularProgressIndicator())
            else if (_slots.isEmpty)
              Text(
                'Bu gün için uygun saat yok. Başka bir gün dene.',
                style: HgText.caption.copyWith(color: c.textMuted),
              )
            else
              Wrap(
                spacing: HgSpace.sm,
                runSpacing: HgSpace.sm,
                children: _slots.map((slot) {
                  final isSelected = identical(_selectedSlot, slot);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: HgSpace.md,
                        vertical: HgSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? c.violet : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(HgRadius.sm),
                      ),
                      child: Text(
                        slot.label,
                        style: HgText.body.copyWith(
                          color: isSelected ? c.onBrand : c.text,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // 5. Telefon + 6. Not + 7. Gönder — saat seçildiyse
            if (_selectedSlot != null) ...[
              SizedBox(height: HgSpace.lg),
              HgFormField(
                label: 'Telefon (zorunlu)',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                hint: '5XX XXX XX XX',
              ),
              SizedBox(height: HgSpace.sm),
              HgFormField(
                label: 'Not (isteğe bağlı)',
                controller: _noteCtrl,
                maxLines: 2,
              ),
              SizedBox(height: HgSpace.lg),
              HgButton(
                label: 'Randevu talebi gönder',
                color: c.violet,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ],
        ],
      ),
    );
  }
}