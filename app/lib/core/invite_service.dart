// Hanagram — davet servisi
//
// Tek sorumluluk: davet kodu doğrulama, kullanma, yönetme.
import 'package:hanagram_design/design.dart';

class InviteService {
  InviteService(this._core);

  final HanagramCore _core;

  List<String> myInviteCodes = const [];

  /// İlk açılışta davet kodları üretir (eğer sistem boşsa).
  void seedFirstRunIfNeeded() {
    try {
      const token = 'hanagram-erken-erisim';
      final setup = _core.callRaw('admin.setup', {'token': token});
      if (setup['ok'] != true) return;

      final overview = _core.callRaw('admin.overview', {'adminToken': token});
      final data = (overview['data'] as Map?)?.cast<String, dynamic>();
      final openInvites = (data?['invitesOpen'] as num?)?.toInt() ?? 0;
      final users = (data?['users'] as num?)?.toInt() ?? 0;
      if (users > 0 || openInvites > 0) return;

      final made = _core.callRaw('admin.createInvites', {
        'adminToken': token,
        'count': 1,
        'maxUses': 1,
      });
      final codes = ((made['data'] as Map?)?['codes'] as List?) ?? const [];
      myInviteCodes = codes.map((e) => '$e').toList();
    } on Exception catch (_) {
      // Web'de çekirdek mevcut değil — sessizce atla.
    }
  }

  /// Davet kodunu doğrular. Geçerliyse davet edenin adını döner.
  ({bool valid, String code, String invitedBy}) checkInvite(String raw) {
    try {
      final r = _core.callRaw('invite.check', {'code': raw});
      if (r['ok'] != true) {
        return (valid: false, code: '${r['code']}', invitedBy: '');
      }
      final d = (r['data'] as Map).cast<String, dynamic>();
      return (
        valid: true,
        code: d['code'] as String? ?? '',
        invitedBy: d['invitedByName'] as String? ?? 'Hanagram',
      );
    } on Exception catch (_) {
      return (valid: false, code: 'ERR_UNAVAILABLE', invitedBy: '');
    }
  }

  /// Kodu kullanır. Hata varsa hata mesajı, yoksa null döner.
  Map<String, dynamic>? redeem(String code, String name, String accountType) {
    try {
      final r = _core.callRaw('invite.redeem', {
        'code': code,
        'name': name,
        'accountType': accountType,
      });
      if (r['ok'] != true) return null;

      final d = (r['data'] as Map).cast<String, dynamic>();
      myInviteCodes = ((d['myInviteCodes'] as List?) ?? const [])
          .map((e) => '$e')
          .toList();
      return d;
    } on Exception catch (_) {
      return null;
    }
  }
}
