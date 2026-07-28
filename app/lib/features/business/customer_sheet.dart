// Hanagram — müşteri ekle/düzenle sheet
//
// appointment_sheet.dart örneğine göre. customer.create veya customer.update çağırır.
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import 'customer_item.dart';
import 'core_error_helper.dart';
class CustomerSheet extends StatefulWidget {
  const CustomerSheet({
    super.key,
    required this.businessId,
    this.customer,
  });

  final String businessId;
  final CustomerItem? customer;

  @override
  State<CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<CustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _tagsCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _emailCtrl = TextEditingController(text: c?.email ?? '');
    _noteCtrl = TextEditingController(text: c?.note ?? '');
    _tagsCtrl = TextEditingController(
        text: c?.tags.isNotEmpty == true ? c!.tags.join(', ') : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final app = AppScope.of(context);
      final c = widget.customer;

      if (c == null) {
        // Yeni müşteri ekle
        app.core.call('customer.create', {
          'businessId': widget.businessId,
          'name': _nameCtrl.text,
          'phone': _phoneCtrl.text,
          'email': _emailCtrl.text,
          'note': _noteCtrl.text,
          'tags': _tagsCtrl.text.split(',').map((t) => t.trim()).toList(),
          'linkedUserId': '',
        });
      } else {
        // Müşteri güncelle
        app.core.call('customer.update', {
          'businessId': widget.businessId,
          'customerId': c.id,
          'name': _nameCtrl.text,
          'phone': _phoneCtrl.text,
          'email': _emailCtrl.text,
          'note': _noteCtrl.text,
          'tags': _tagsCtrl.text.split(',').map((t) => t.trim()).toList(),
        });
      }

      if (mounted) Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extractErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final isEdit = widget.customer != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(HgSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(HgRadius.lg)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Müşteri düzenle' : 'Yeni müşteri',
                style: HgText.title.copyWith(color: c.text),
              ),
              const SizedBox(height: HgSpace.lg),
              HgFormField(
                label: 'Ad (zorunlu)',
                controller: _nameCtrl,
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Telefon',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                hint: '+905321112233',
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'E-posta',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Not',
                controller: _noteCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: HgSpace.md),
              HgFormField(
                label: 'Etiketler (virgülle ayır)',
                controller: _tagsCtrl,
                hint: 'VIP, sadık müşteri',
              ),
              const SizedBox(height: HgSpace.xl),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: HgButton(
                    label: isEdit ? 'Güncelle' : 'Ekle',
                    color: c.violet,
                    loading: _isSaving,
                    onPressed: _save,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
