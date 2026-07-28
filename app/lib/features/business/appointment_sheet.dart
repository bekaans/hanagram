import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import 'core_error_helper.dart';

class AppointmentSheet extends StatefulWidget {
  const AppointmentSheet({
    super.key,
    required this.businessId,
    required this.dayMs,
  });

  final String businessId;
  final int dayMs;

  @override
  State<AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<AppointmentSheet> {
  List<int> _slots = const [];
  int? _selectedSlot;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _slotsError;

  final _customerNameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    try {
      final app = AppScope.of(context);
      final result = app.core.call('appointment.slots', {
        'businessId': widget.businessId,
        'dayMs': widget.dayMs,
      });
      final list = (result['slots'] as List?) ?? const [];
      _slots = list.map((e) => (e as num).toInt()).toList();
      _slotsError = null;
    } on Exception catch (e) {
      _slots = const [];
      _slotsError = extractErrorMessage(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canSubmit =>
      _selectedSlot != null &&
      _customerNameController.text.trim().isNotEmpty &&
      !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      final app = AppScope.of(context);
      app.core.call('appointment.create', {
        'businessId': widget.businessId,
        'at': _selectedSlot,
        'customerName': _customerNameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatSlot(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = bottomInset > 0 ? bottomInset : HgSpace.lg;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          HgSpace.lg,
          HgSpace.lg,
          HgSpace.lg,
          bottomPadding,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: HgSpace.lg),
              Text(
                'Yeni randevu',
                style: HgText.title.copyWith(color: c.text),
              ),
              const SizedBox(height: HgSpace.xl),
              _buildSlotPicker(c),
              const SizedBox(height: HgSpace.xl),
              _buildNameField(c),
              const SizedBox(height: HgSpace.md),
              _buildPhoneField(c),
              const SizedBox(height: HgSpace.xl),
              SizedBox(
                width: double.infinity,
                child: BrandButton(
                  label: 'Ekle',
                  onPressed: _canSubmit ? _submit : null,
                  busy: _isSubmitting,
                ),
              ),
              const SizedBox(height: HgSpace.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotPicker(HgColors c) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_slotsError != null || _slots.isEmpty) {
      return Text(
        _slotsError ?? 'Bugün için boş slot yok',
        style: HgText.body.copyWith(color: c.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saat seçin', style: HgText.bodyStrong.copyWith(color: c.text)),
        const SizedBox(height: HgSpace.sm),
        Wrap(
          spacing: HgSpace.sm,
          runSpacing: HgSpace.sm,
          children: _slots.map((slot) {
            final selected = _selectedSlot == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedSlot = slot),
              child: HgChip(
                label: _formatSlot(slot),
                color: selected ? c.violet : c.textMuted,
                filled: selected,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNameField(HgColors c) {
    return TextField(
      controller: _customerNameController,
      style: HgText.body.copyWith(color: c.text),
      cursorColor: c.violet,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Müşteri adı',
        labelStyle: HgText.body.copyWith(color: c.textMuted),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(HgRadius.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.violet),
          borderRadius: BorderRadius.circular(HgRadius.md),
        ),
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.all(HgSpace.md),
      ),
    );
  }

  Widget _buildPhoneField(HgColors c) {
    return TextField(
      controller: _phoneController,
      style: HgText.body.copyWith(color: c.text),
      cursorColor: c.violet,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Telefon (isteğe bağlı)',
        labelStyle: HgText.body.copyWith(color: c.textMuted),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(HgRadius.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.violet),
          borderRadius: BorderRadius.circular(HgRadius.md),
        ),
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.all(HgSpace.md),
      ),
    );
  }
}
