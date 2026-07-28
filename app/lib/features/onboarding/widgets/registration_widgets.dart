// Hanagram — kayıt akışı yardımcı widget'ları
//
// İletişim adımı, OTP doğrulama, profil fotoğrafı seçim widget'ları.
import '../../../core/web_compat.dart';
import '../../../core/platform_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hanagram_design/design.dart';
import '../../../core/media_service.dart';
import '../../../core/referral_service.dart';

// ─── Eposta/Telefon toggle ───

class ContactToggle extends StatelessWidget {
  const ContactToggle({
    super.key,
    required this.isEmail,
    required this.onChanged,
  });

  final bool isEmail;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              label: 'E-posta',
              icon: Icons.email_outlined,
              selected: isEmail,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _ToggleOption(
              label: 'Telefon',
              icon: Icons.phone_outlined,
              selected: !isEmail,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: HgMotion.normal,
        padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
        decoration: BoxDecoration(
          gradient: selected ? c.brand : null,
          borderRadius: BorderRadius.circular(HgRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? c.onBrand : c.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: HgText.bodyStrong.copyWith(
                color: selected ? c.onBrand : c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── OTP doğrulama alanı ───

class OtpField extends StatelessWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.error,
  });

  final TextEditingController controller;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Doğrulama kodu', style: HgText.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: HgSpace.sm),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: HgText.mono.copyWith(color: c.text, fontSize: 22),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: '– – – – – –',
            counterText: '',
            hintStyle: HgText.mono.copyWith(color: c.textFaint, fontSize: 22),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HgRadius.md),
              borderSide: BorderSide(color: error != null ? c.danger : c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HgRadius.md),
              borderSide: BorderSide(color: c.violet, width: 1.6),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: HgSpace.xs),
          Text(error!, style: HgText.small.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}

// ─── Kullanıcı adı alanı (benzersizlik kontrolü ile) ───

class UsernameField extends StatefulWidget {
  const UsernameField({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<bool>? onChanged;

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  bool? _available;
  bool _checking = false;

  Future<void> _checkAvailability(String value) async {
    if (value.length < 3) {
      setState(() => _available = null);
      return;
    }

    setState(() => _checking = true);
    final available = await ReferralService.isUsernameAvailable(value);
    if (mounted) {
      setState(() {
        _available = available;
        _checking = false;
      });
      widget.onChanged?.call(available);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kullanıcı adı', style: HgText.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: HgSpace.sm),
        TextField(
          controller: widget.controller,
          onChanged: _checkAvailability,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: HgText.body.copyWith(color: c.text),
          decoration: InputDecoration(
            hintText: 'kullaniciadi',
            prefixText: '@ ',
            prefixStyle: HgText.bodyStrong.copyWith(color: c.violet),
            hintStyle: HgText.body.copyWith(color: c.textFaint),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: HgSpace.lg, vertical: HgSpace.lg),
            suffixIcon: _checking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _available == true
                    ? Icon(Icons.check_circle, color: c.success, size: 22)
                    : _available == false
                        ? Icon(Icons.cancel, color: c.danger, size: 22)
                        : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HgRadius.md),
              borderSide: BorderSide(
                color: _available == false
                    ? c.danger
                    : _available == true
                        ? c.success
                        : c.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(HgRadius.md),
              borderSide: BorderSide(
                color: _available == false
                    ? c.danger
                    : _available == true
                        ? c.success
                        : c.violet,
                width: 1.6,
              ),
            ),
          ),
        ),
        if (_available == false)
          Padding(
            padding: const EdgeInsets.only(top: HgSpace.xs),
            child: Text(
              'Bu kullanıcı adı alınmış.',
              style: HgText.small.copyWith(color: c.danger),
            ),
          ),
      ],
    );
  }
}

// ─── Profil fotoğrafı seçim widget'ı ───

class ProfilePhotoPicker extends StatefulWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.userId,
    this.onPhotoSelected,
  });

  final String userId;
  final ValueChanged<String>? onPhotoSelected;

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  File? _imageFile;
  bool _uploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _uploading = true;
    });

    final url = await MediaService.uploadAvatar(_imageFile!, widget.userId);
    setState(() => _uploading = false);

    if (url != null) {
      widget.onPhotoSelected?.call(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _imageFile == null ? c.brand : null,
                  color: _imageFile == null ? null : c.surfaceAlt,
                  border: Border.all(color: c.border, width: 2),
                ),
                child: _imageFile != null
                    ? ClipOval(
                        child: PlatformImage(
                          file: _imageFile!,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                      )
                    : Icon(
                        Icons.camera_alt_outlined,
                        size: 32,
                        color: c.onBrand,
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.violet,
                    border: Border.all(color: c.bg, width: 2),
                  ),
                  child: _uploading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.add, size: 16, color: c.onBrand),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HgSpace.sm),
        Text(
          'Profil fotoğrafı (isteğe bağlı)',
          style: HgText.caption.copyWith(color: c.textFaint),
        ),
      ],
    );
  }
}
