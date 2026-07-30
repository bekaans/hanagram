// Hanagram — ekip servisi (Supabase business_groups/group_members)
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class TeamService {
  TeamService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Kullanıcının sahibi/üyesi olduğu ekipleri, üye listeleriyle getir.
  static Future<List<Map<String, dynamic>>> getMyTeams() async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return [];

      final memberRows =
          await _db.from('group_members').select('group_id').eq('user_id', myId);
      final groupIds = (memberRows as List)
          .map((r) => (r as Map)['group_id'] as String)
          .toSet();
      if (groupIds.isEmpty) return [];

      final groups = await _db
          .from('business_groups')
          .select('id, name, owner_id')
          .inFilter('id', groupIds.toList())
          .order('created_at', ascending: false);

      final result = <Map<String, dynamic>>[];
      for (final row in (groups as List)) {
        final g = row as Map<String, dynamic>;
        final groupId = g['id'] as String;

        final members = await _db
            .from('group_members')
            .select('role, user:users!group_members_user_id_fkey(id, full_name)')
            .eq('group_id', groupId);

        final memberList =
            (members as List).cast<Map<String, dynamic>>().map((m) {
          final u = m['user'] as Map<String, dynamic>?;
          return {
            'userId': u?['id'] ?? '',
            'name': u?['full_name'] ?? '',
            'role': m['role'] == 'member' ? 'Üye' : 'Yönetici',
          };
        }).toList();

        result.add({
          'id': groupId,
          'name': g['name'],
          'ownerId': g['owner_id'],
          'members': memberList,
        });
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Yeni ekip oluştur — kurucu otomatik owner üye olarak eklenir.
  static Future<String?> createTeam(String name) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return null;

      final group = await _db.from('business_groups').insert({
        'owner_id': myId,
        'name': name,
      }).select('id').maybeSingle();

      final groupId = group?['id'] as String?;
      if (groupId == null) return null;

      await _db.from('group_members').insert({
        'group_id': groupId,
        'user_id': myId,
        'role': 'owner',
      });

      return groupId;
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcı adı/isme göre ara (ekibe davet edilebilecek kişiler).
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null || query.trim().length < 2) return [];

      final result = await _db
          .from('users')
          .select('id, full_name, username, avatar_url')
          .neq('id', myId)
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);

      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Ekibe üye ekle (davet kabul akışı yerine — V1 doğrudan ekleme).
  static Future<bool> addMember(String groupId, String userId) async {
    try {
      await _db.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ekibe atanmış paylaşımlı görevleri getir (tasks.group_id).
  static Future<List<Map<String, dynamic>>> getTeamTasks(String groupId) async {
    try {
      final result = await _db
          .from('tasks')
          .select('title, status, assignee:users!tasks_assigned_to_fkey(full_name)')
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      return (result as List).cast<Map<String, dynamic>>().map((t) {
        final assignee = t['assignee'] as Map<String, dynamic>?;
        return {
          'title': t['title'],
          'assignee': assignee?['full_name'],
          'isDone': t['status'] == 'completed',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Ekiple paylaşılan CRM kayıtlarını getir (crm_entries.group_id).
  static Future<List<Map<String, dynamic>>> getTeamCrm(String groupId) async {
    try {
      final result = await _db
          .from('crm_entries')
          .select('customer_name, notes')
          .eq('group_id', groupId)
          .order('date', ascending: false);

      return (result as List).cast<Map<String, dynamic>>().map((e) {
        return {
          'clientName': e['customer_name'] ?? '',
          'note': e['notes'] ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
