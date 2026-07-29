// Hanagram — OneSignal native implementasyonu
//
// onesignal_flutter paketini import eder.
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalBridge {
  static void initialize(String appId) {
    OneSignal.initialize(appId);
  }

  static void optIn() {
    OneSignal.User.pushSubscription.optIn();
  }

  static void addClickListener(void Function(dynamic event) handler) {
    OneSignal.Notifications.addClickListener(handler);
  }

  static void addAlias(String label, String value) {
    OneSignal.User.addAlias(label, value);
  }
}
