// Hanagram — doğrulama form sayfası (bottom sheet)
//
// Kişisel: ad soyad + TC no + ön/arka kimlik fotoğrafı
// İşletme: işletme adı + vergi no + vergi levhası + adres
// İstek admin paneline gider, 1 ay içinde yanıtlanmazsa silinir.
//
// Güvenlik: sunucu tarafında input validation zorunlu,
// istemci tarafı sadece UX için. Dosya boyutu ve MIME kontrolü var.
import '../../core/web_compat.dart';
import '../../core/platform_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hanagram_design/design.dart';
import '../../core/verification_service.dart';

/// Maksimum dosya boyutu (5MB — guvenli-kod kuralı 8).
const int _maxFileSizeBytes = 5 * 1024 * 1024;

class VerificationSheet extends StatefulWidget {
  const VerificationSheet({
    super.key,
    required this.isBusiness,
    required this.onSubmitted,
  });

  final bool isBusiness;
  final VoidCallback onSubmitted;

  @override
  State<VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<VerificationSheet> {
  final _nameCtrl = TextEditingController();
  final _tcCtrl = TextEditingController();
  final _bizNameCtrl = TextEditingController();
  final _taxNoCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  File? _frontImage;
  File? _backImage;
  File? _taxCertImage;
  bool _sending = false;
  String _error = '';

  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tcCtrl.dispose();
    _bizNameCtrl.dispose();
    _taxNoCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ─── Input Validation (guvenli-kod kuralı 3) ───

  /// TC Kimlik No: 11 haneli, rakamlardan oluşmalı.
  bool _isValidTcNo(String tc) {
    if (tc.length != 11) return false;
    if (!RegExp(r'^\d{11}$').hasMatch(tc)) return false;
    // İlk hane 0 olamaz
    if (tc.startsWith('0')) return false;
    // Basit checksum kontrolü (10. ve 11. hane)
    final digits = tc.split('').map(int.parse).toList();
    final sum1 = digits[0] + digits[2] + digits[4] + digits[6] + digits[8];
    final sum2 = digits[1] + digits[3] + digits[5] + digits[7];
    final check1 = (sum1 * 7 - sum2) % 10;
    final check2 = (sum1 + sum2 * 2 + digits[9]) % 10;
    return check1 == digits[9] && check2 == digits[10];
  }

  /// Vergi Numarası: 10 veya 11 haneli rakam.
  bool _isValidTaxNo(String no) {
    return RegExp(r'^\d{10,11}$').hasMatch(no);
  }

  /// Dosya boyutu ve MIME kontrolü (guvenli-kod kuralı 8).
  Future<File?> _validateAndPickImage(String target) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(HgSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return null;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final file = File(picked.path);

    // Dosya boyutu kontrolü (5MB limit)
    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      if (mounted) {
        setState(() => _error = 'Dosya boyutu 5MB\'dan küçük olmalı.');
      }
      return null;
    }

    // MIME tipi kontrolü (guvenli-kod kuralı 8)
    final ext = picked.path.split('.').last.toLowerCase();
    final allowedExts = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowedExts.contains(ext)) {
      if (mounted) {
        setState(() => _error = 'Sadece JPG, PNG veya WebP dosyaları yüklenebilir.');
      }
      return null;
    }

    if (mounted) setState(() => _error = '');
    return file;
  }

  Future<void> _pickImage(String target) async {
    final file = await _validateAndPickImage(target);
    if (file == null) return;

    setState(() {
      switch (target) {
        case 'front':
          _frontImage = file;
        case 'back':
          _backImage = file;
        case 'tax':
          _taxCertImage = file;
      }
    });
  }

  Future<void> _submit() async {
    // ── Sunucu tarafı validasyon öncesi istemci kontrolü ──
    if (widget.isBusiness) {
      if (_bizNameCtrl.text.trim().length < 2) {
        setState(() => _error = 'İşletme adı en az 2 karakter olmalı.');
        return;
      }
      if (!_isValidTaxNo(_taxNoCtrl.text.trim())) {
        setState(() => _error = 'Vergi numarası 10 veya 11 haneli rakamlardan oluşmalı.');
        return;
      }
      if (_addressCtrl.text.trim().length < 5) {
        setState(() => _error = 'Adres en az 5 karakter olmalı.');
        return;
      }
      if (_taxCertImage == null) {
        setState(() => _error = 'Vergi levhası fotoğrafı yükleyin.');
        return;
      }
    } else {
      if (_nameCtrl.text.trim().length < 2) {
        setState(() => _error = 'Ad Soyad en az 2 karakter olmalı.');
        return;
      }
      if (!_isValidTcNo(_tcCtrl.text.trim())) {
        setState(() => _error = 'Geçersiz TC Kimlik Numarası. 11 haneli olmalı.');
        return;
      }
      if (_frontImage == null || _backImage == null) {
        setState(() => _error = 'Kimlik fotoğraflarının her ikisini de yükleyin.');
        return;
      }
    }

    setState(() {
      _sending = true;
      _error = '';
    });

    bool success = false;

    try {
      if (widget.isBusiness) {
        success = await VerificationService.submitBusinessVerification(
          businessName: _bizNameCtrl.text.trim(),
          taxNo: _taxNoCtrl.text.trim(),
          taxCertificate: _taxCertImage!,
          businessAddress: _addressCtrl.text.trim(),
        ) != null;
      } else {
        success = await VerificationService.submitPersonalVerification(
          fullName: _nameCtrl.text.trim(),
          tcNo: _tcCtrl.text.trim(),
          frontImage: _frontImage!,
          backImage: _backImage!,
        ) != null;
      }
    } catch (_) {
      // guvenli-kod kuralı 9: stack trace'i istemciye dönme
      success = false;
    }

    if (mounted) {
      setState(() => _sending = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doğrulama isteği gönderildi! İnceleniyor…'),
          ),
        );
        widget.onSubmitted();
      } else {
        setState(() {
          _error = _error.isEmpty ? 'Bir hata oluştu, tekrar deneyin.' : _error;
        });
      }
    }
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
              // Tutamaç
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

              Text(
                widget.isBusiness
                    ? 'İşletme Doğrulaması'
                    : 'Kişisel Doğrulama',
                style: HgText.title
                    .copyWith(color: c.text, shadows: null),
              ),
              const SizedBox(height: HgSpace.sm),
              Text(
                widget.isBusiness
                    ? 'İşletme bilgilerinizi ve vergi levhanızı yükleyin. Admin onayladığında profilinize sarı yıldız eklenecek.'
                    : 'Kimlik bilgilerinizi yükleyin. Onaylandığında profilinize mavi yıldız eklenecek.',
                style: HgText.caption.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: HgSpace.lg),

              // ─── Kişisel Doğrulama Formu ───
              if (!widget.isBusiness) ...[
                _inputField(c, _nameCtrl, 'Ad Soyad',
                    maxLength: 100),
                const SizedBox(height: HgSpace.md),
                _inputField(c, _tcCtrl, 'TC Kimlik No',
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ]),
                const SizedBox(height: HgSpace.lg),
                Text('Kimlik Fotografları',
                    style: HgText.bodyStrong
                        .copyWith(color: c.text)),
                const SizedBox(height: HgSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: _imagePicker(
                        c,
                        label: 'Ön Yüz',
                        image: _frontImage,
                        onTap: () => _pickImage('front'),
                      ),
                    ),
                    const SizedBox(width: HgSpace.md),
                    Expanded(
                      child: _imagePicker(
                        c,
                        label: 'Arka Yüz',
                        image: _backImage,
                        onTap: () => _pickImage('back'),
                      ),
                    ),
                  ],
                ),
              ],

              // ─── İşletme Doğrulama Formu ───
              if (widget.isBusiness) ...[
                _inputField(c, _bizNameCtrl, 'İşletme Adı',
                    maxLength: 100),
                const SizedBox(height: HgSpace.md),
                _inputField(c, _taxNoCtrl, 'Vergi Numarası',
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ]),
                const SizedBox(height: HgSpace.md),
                _inputField(c, _addressCtrl, 'İşletme Adresi',
                    maxLines: 2, maxLength: 200),
                const SizedBox(height: HgSpace.lg),
                Text('Vergi Levhası',
                    style: HgText.bodyStrong
                        .copyWith(color: c.text)),
                const SizedBox(height: HgSpace.sm),
                _imagePicker(
                  c,
                  label: 'Vergi Levhası Fotoğrafı',
                  image: _taxCertImage,
                  onTap: () => _pickImage('tax'),
                  wide: true,
                ),
              ],

              const SizedBox(height: HgSpace.xl),

              // Hata mesajı (guvenli-kod kuralı 9: genel mesaj)
              if (_error.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(HgSpace.md),
                  decoration: BoxDecoration(
                    color: c.danger.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(HgRadius.sm),
                    border: Border.all(
                      color: c.danger.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: c.danger),
                      const SizedBox(width: HgSpace.sm),
                      Expanded(
                        child: Text(
                          _error,
                          style: HgText.caption
                              .copyWith(color: c.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: HgSpace.md),
              ],

              // Uyarı
              Container(
                padding: const EdgeInsets.all(HgSpace.md),
                decoration: BoxDecoration(
                  color: c.warning.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(HgRadius.sm),
                  border: Border.all(
                    color: c.warning.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: c.warning),
                    const SizedBox(width: HgSpace.sm),
                    Expanded(
                      child: Text(
                        'İsteğiniz 1 ay içinde değerlendirilmezse bilgileriniz otomatik olarak silinir.',
                        style: HgText.caption
                            .copyWith(color: c.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HgSpace.xl),

              // Gönder butonu
              SizedBox(
                width: double.infinity,
                child: BrandButton(
                  label: _sending ? 'Gönderiliyor…' : 'İsteği Gönder',
                  icon: _sending ? null : Icons.send,
                  onPressed: _sending || !_canSubmit()
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

  bool _canSubmit() {
    if (_sending) return false;
    if (widget.isBusiness) {
      return _bizNameCtrl.text.trim().length >= 2 &&
          _isValidTaxNo(_taxNoCtrl.text.trim()) &&
          _addressCtrl.text.trim().length >= 5 &&
          _taxCertImage != null;
    } else {
      return _nameCtrl.text.trim().length >= 2 &&
          _isValidTcNo(_tcCtrl.text.trim()) &&
          _frontImage != null &&
          _backImage != null;
    }
  }

  Widget _inputField(
    HgColors c,
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: HgText.body.copyWith(color: c.text),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: HgText.body.copyWith(color: c.textFaint),
        filled: true,
        fillColor: c.surfaceAlt,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgRadius.md),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }

  Widget _imagePicker(
    HgColors c, {
    required String label,
    required File? image,
    required VoidCallback onTap,
    bool wide = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: wide ? 140 : 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: image != null
              ? c.violet.withValues(alpha: 0.05)
              : c.surfaceAlt,
          borderRadius: BorderRadius.circular(HgRadius.md),
          border: Border.all(
            color: image != null
                ? c.violet.withValues(alpha: 0.3)
                : c.border,
            width: image != null ? 1.5 : 0.5,
          ),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius:
                    BorderRadius.circular(HgRadius.md),
                child: PlatformImage(file: image, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo,
                      size: 28, color: c.textMuted),
                  const SizedBox(height: HgSpace.sm),
                  Text(label,
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
                  const SizedBox(height: 2),
                  Text('Dokunun',
                      style: HgText.small
                          .copyWith(color: c.textFaint)),
                ],
              ),
      ),
    );
  }
}
