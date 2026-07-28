// Hanagram — ayarlar durum yöneticisi
//
// Tema tercihi, bildirim ayarları ve kişiselleştirme seçeneklerini tutar.
// C++ çekirdeğe bağımlı değil — bağımsız bir yerel depo kullanır.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }

  Future<void> toggleReadReceipts(bool value) async {
    _showReadReceipts = value;
    await _prefs?.setBool('readReceipts', value);
    notifyListeners();
  }

  Future<void> toggleHapticFeedback(bool value) async {
    _hapticFeedback = value;
    await _prefs?.setBool('haptic', value);
    notifyListeners();
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
