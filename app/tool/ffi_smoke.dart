// FFI duman testi: Dart → C ABI → C++ çekirdek zincirinin gerçekten çalıştığını doğrular.
// Çalıştır:  cd app && dart run ../tools/ffi_smoke.dart
import 'dart:io';
import 'package:hanagram/core/ffi.dart';

void main() {
  final core = HanagramCore.start('');
  print('çekirdek sürümü : ${core.version}');

  final ping = core.call('system.ping');
  print('ping            : ${ping['pong']}');

  final setup = core.callRaw('admin.setup', {'token': 'duman-testi-anahtar'});
  print('admin kurulumu  : ${setup['ok']}');

  final made = core.call('admin.createInvites',
      {'adminToken': 'duman-testi-anahtar', 'count': 2});
  final codes = (made['codes'] as List).cast<String>();
  print('davet kodları   : $codes');

  final joined = core.call('invite.redeem', {
    'code': codes.first,
    'name': 'Berke Kaan Saraç',
    'accountType': 'business',
  });
  final user = joined['user'] as Map;
  final membership = joined['membership'] as Map;
  print('üye             : ${user['name']} (@${user['handle']}) '
      '#${membership['memberNumber']}');
  print('kendi kodları   : ${joined['myInviteCodes']}');

  final second = core.call('invite.redeem', {
    'code': (joined['myInviteCodes'] as List).first,
    'name': 'Ikinci Uye',
  });
  final u2 = (second['user'] as Map)['id'];

  for (final t in ['guzellik', 'medikal', 'guzellik']) {
    core.call('post.create', {
      'authorId': u2,
      'caption': '$t içeriği',
      'topics': [t],
    });
  }

  final feed = core.call('feed.get', {'userId': user['id'], 'limit': 5});
  print('akış öğesi      : ${(feed['items'] as List).length}');
  final first = (feed['items'] as List).first as Map;
  print('ilk öğe         : "${first['caption']}"  skor=${(first['_why'] as Map)['score']}');

  core.call('signal.record',
      {'userId': user['id'], 'itemId': first['id'], 'kind': 'like'});
  final feed2 = core.call('feed.get', {'userId': user['id'], 'limit': 5});
  print('profil güveni   : ${feed2['profileConfidence']}');

  final ov = core.call('admin.overview', {'adminToken': 'duman-testi-anahtar'});
  print('admin özeti     : ${ov['users']} kullanıcı, ${ov['posts']} gönderi');
  print('ağırlıklar      : ${ov['weights']}');

  core.dispose();
  print('\nFFI zinciri çalışıyor: Dart → C ABI → C++ çekirdek');
  exit(0);
}
