// Hanagram — ayarlar durum yöneticisi
//
// Tema tercihi, bildirim ayarları ve kişiselleştirme seçeneklerini tutar.
// C++ çekirdeğe bağımlı değil. Çoğu tercih sadece yerelde saklanır, ama
// "Çevrimiçi görünürlük" ve "Okundu bilgisi" BAŞKA kullanıcıların istemcisi
// tarafından okunması gerektiği için users tablosuna da yazılır.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/supabase_service.dart';

class SettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // Tema: 'system', 'light', 'dark'
  String _themeMode = 'system';
  String get themeMode => _themeMode;

  // Bildirimler
  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  bool _messageNotifications = true;
  bool get messageNotifications => _messageNotifications;

  bool _appointmentReminders = true;
  bool get appointmentReminders => _appointmentReminders;

  // Kişiselleştirme
  bool _showOnlineStatus = true;
  bool get showOnlineStatus => _showOnlineStatus;

  bool _showReadReceipts = true;
  bool get showReadReceipts => _showReadReceipts;

  bool _hapticFeedback = true;
  bool get hapticFeedback => _hapticFeedback;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = _prefs?.getString('themeMode') ?? 'system';
    _notificationsEnabled = _prefs?.getBool('notifications') ?? true;
    _messageNotifications = _prefs?.getBool('msgNotif') ?? true;
    _appointmentReminders = _prefs?.getBool('aptRemind') ?? true;
    _showOnlineStatus = _prefs?.getBool('onlineStatus') ?? true;
    _showReadReceipts = _prefs?.getBool('readReceipts') ?? true;
    _hapticFeedback = _prefs?.getBool('haptic') ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    await _prefs?.setString('themeMode', mode);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    await _prefs?.setBool('notifications', value);
    notifyListeners();
  }

  Future<void> toggleMessageNotifications(bool value) async {
    _messageNotifications = value;
    await _prefs?.setBool('msgNotif', value);
    notifyListeners();
  }

  Future<void> toggleAppointmentReminders(bool value) async {
    _appointmentReminders = value;
    await _prefs?.setBool('aptRemind', value);
    notifyListeners();
  }

  Future<void> toggleOnlineStatus(bool value) async {
    _showOnlineStatus = value;
    await _prefs?.setBool('onlineStatus', value);
    notifyListeners();
    await _syncPrivacyField('show_online_status', value);
  }

  Future<void> toggleReadReceipts(bool value) async {
    _showReadReceipts = value;
    await _prefs?.setBool('readReceipts', value);
    notifyListeners();
    await _syncPrivacyField('show_read_receipts', value);
  }

  Future<void> toggleHapticFeedback(bool value) async {
    _hapticFeedback = value;
    await _prefs?.setBool('haptic', value);
    notifyListeners();
  }

  /// Gizlilik tercihini users tablosuna yaz — başkaları bunu okuyabilsin diye.
  Future<void> _syncPrivacyField(String column, bool value) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return;
      await SupabaseService.client.from('users').update({column: value}).eq('id', userId);
    } catch (_) {
      // Senkronizasyon başarısız olursa yerel tercih yine de geçerli kalır.
    }
  }

  /// Dokunsal geri bildirim — açıksa hafif titreşim verir, ayarlarda kapatılabilir.
  void hapticTap() {
    if (_hapticFeedback) HapticFeedback.lightImpact();
  }

  /// Şu an aktif olduğumu bildir (basit "son görülme" — gerçek zamanlı presence değil).
  Future<void> pingOnline() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return;
      await SupabaseService.client.from('users').update({
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
  }

  Brightness get effectiveBrightness {
    switch (_themeMode) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      default:
        return Brightness.dark; // varsayılan koyu
    }
  }
}

/// Ayarları ağaca taşır — tüm ekranlar tek bir SettingsProvider kullanır.
class SettingsScope extends InheritedNotifier<SettingsProvider> {
  const SettingsScope({
    super.key,
    required SettingsProvider settings,
    required super.child,
  }) : super(notifier: settings);

  static SettingsProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope bulunamadı');
    return scope!.notifier!;
  }
}
