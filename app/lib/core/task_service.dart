// Hanagram — görev servisi
//
// Tek sorumluluk: görev CRUD + takvim sorguları.
// Supabase tasks ve appointments tablolarıyla çalışır.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'supabase_service.dart';

/// Görev durumları.
enum TaskStatus { pending, accepted, inProgress, completed, rejected }

/// Görev öncelikleri.
enum TaskPriority { low, medium, high, urgent }

/// Görev modeli.
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.createdBy,
    this.description = '',
    this.assignedTo,
    this.groupId,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.dueTime,
    this.completedAt,
    required this.createdAt,
    // Katılımcı bilgileri (join ile)
    this.creatorName = '',
    this.assigneeName = '',
  });

  final String id;
  final String title;
  final String createdBy;
  final String description;
  final String? assignedTo;
  final String? groupId;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? dueTime;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String creatorName;
  final String assigneeName;

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        createdBy: j['created_by'] as String? ?? '',
        description: j['description'] as String? ?? '',
        assignedTo: j['assigned_to'] as String?,
        groupId: j['group_id'] as String?,
        status: _parseStatus(j['status'] as String?),
        priority: _parsePriority(j['priority'] as String?),
        dueDate: j['due_date'] != null
            ? DateTime.tryParse(j['due_date'] as String)
            : null,
        dueTime: j['due_time'] as String?,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String)
            : null,
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        creatorName: j['creator_name'] as String? ?? '',
        assigneeName: j['assignee_name'] as String? ?? '',
      );

  static TaskStatus _parseStatus(String? s) {
    switch (s) {
      case 'accepted':
        return TaskStatus.accepted;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'rejected':
        return TaskStatus.rejected;
      default:
        return TaskStatus.pending;
    }
  }

  static TaskPriority _parsePriority(String? p) {
    switch (p) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'urgent':
        return TaskPriority.urgent;
      default:
        return TaskPriority.medium;
    }
  }
}

/// Randevu modeli.
class Appointment {
  const Appointment({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.createdBy,
    this.description = '',
    this.attendeeId,
    this.groupId,
    this.endTime,
    this.status = 'pending',
    this.attendeeName = '',
  });

  final String id;
  final String title;
  final DateTime date;
  final String startTime;
  final String createdBy;
  final String description;
  final String? attendeeId;
  final String? groupId;
  final String? endTime;
  final String status;
  final String attendeeName;

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        startTime: j['start_time'] as String? ?? '',
        createdBy: j['created_by'] as String? ?? '',
        description: j['description'] as String? ?? '',
        attendeeId: j['attendee_id'] as String?,
        groupId: j['group_id'] as String?,
        endTime: j['end_time'] as String?,
        status: j['status'] as String? ?? 'pending',
        attendeeName: j['attendee_name'] as String? ?? '',
      );
}

class TaskService {
  TaskService._();

  static SupabaseClient get _db => SupabaseService.client;

  // ─── GÖREVLER ───

  /// Yeni görev oluştur + otomatik CRM kaydı ekle (eğer satış ise).
  /// Etiketleme: kişi işletme grubunda VE takip ediyor olmalı.
  static Future<String?> createTask({
    required String title,
    String description = '',
    String? assignedTo,
    String? groupId,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? dueTime,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;

      // Etiketleme kontrolü: grup + takip zorunluluğu
      if (assignedTo != null && groupId != null) {
        final canTag = await canTagUser(
          targetUserId: assignedTo,
          groupId: groupId,
        );
        if (!canTag) return null; // Etiketleme engellendi
      }

      final result = await _db.from('tasks').insert({
        'title': title,
        'description': description,
        'created_by': userId,
        'assigned_to': assignedTo,
        'group_id': groupId,
        'priority': priority.name,
        'due_date': dueDate?.toIso8601String().split('T').first,
        'due_time': dueTime,
      }).select('id').maybeSingle();

      final taskId = result?['id'] as String?;

      // Atanan kişiye push bildirim gönder
      if (taskId != null && assignedTo != null && assignedTo != userId) {
        final creatorProfile = await _db
            .from('users')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        final creatorName = creatorProfile?['full_name'] as String? ?? 'Birisi';

        final notifBody = '$creatorName sana bir görev atadı: $title';
        NotificationService.sendToUser(
          targetUserId: assignedTo,
          title: 'Yeni Görev',
          body: notifBody,
          data: {'task_id': taskId, 'type': 'new_task'},
        );
        NotificationService.record(
          targetUserId: assignedTo,
          type: 'task',
          title: 'Yeni Görev',
          body: notifBody,
          data: {'task_id': taskId},
        );
      }

      return taskId;
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcının görevlerini getir (oluşturduğu + atanan).
  static Future<List<TaskItem>> getMyTasks({
    TaskStatus? status,
    int limit = 50,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final result = await _db
          .from('tasks')
          .select('''
            *,
            creator:users!tasks_created_by_fkey(full_name),
            assignee:users!tasks_assigned_to_fkey(full_name)
          ''')
          .or('created_by.eq.$userId,assigned_to.eq.$userId')
          .order('created_at', ascending: false)
          .limit(limit);

      return (result as List).map((j) {
        final map = j as Map<String, dynamic>;
        final creator = map['creator'] as Map<String, dynamic>?;
        final assignee = map['assignee'] as Map<String, dynamic>?;
        return TaskItem.fromJson({
          ...map,
          'creator_name': creator?['full_name'] ?? '',
          'assignee_name': assignee?['full_name'] ?? '',
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Belirli bir tarihteki görevleri getir (takvim için).
  static Future<List<TaskItem>> getTasksForDate(DateTime date) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final dateStr = date.toIso8601String().split('T').first;

      final result = await _db
          .from('tasks')
          .select('''
            *,
            creator:users!tasks_created_by_fkey(full_name),
            assignee:users!tasks_assigned_to_fkey(full_name)
          ''')
          .eq('due_date', dateStr)
          .or('created_by.eq.$userId,assigned_to.eq.$userId')
          .order('due_time', ascending: true);

      return (result as List).map((j) {
        final map = j as Map<String, dynamic>;
        final creator = map['creator'] as Map<String, dynamic>?;
        final assignee = map['assignee'] as Map<String, dynamic>?;
        return TaskItem.fromJson({
          ...map,
          'creator_name': creator?['full_name'] ?? '',
          'assignee_name': assignee?['full_name'] ?? '',
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Görev durumunu güncelle.
  static Future<bool> updateTaskStatus(
      String taskId, TaskStatus newStatus) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.name,
      };
      if (newStatus == TaskStatus.completed) {
        updateData['completed_at'] = DateTime.now().toIso8601String();
      }

      await _db.from('tasks').update(updateData).eq('id', taskId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── RANDEVULAR ───

  /// Yeni randevu oluştur + otomatik CRM kaydı.
  static Future<String?> createAppointment({
    required String title,
    required DateTime date,
    required String startTime,
    String description = '',
    String? attendeeId,
    String? groupId,
    String? endTime,
    String customerName = '',
    String customerPhone = '',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;

      final result = await _db.from('appointments').insert({
        'title': title,
        'description': description,
        'created_by': userId,
        'attendee_id': attendeeId,
        'group_id': groupId,
        'date': date.toIso8601String().split('T').first,
        'start_time': startTime,
        'end_time': endTime,
      }).select('id').maybeSingle();

      final apptId = result?['id'] as String?;

      // Otomatik CRM kaydı (randevu müşteri bilgisiyle)
      if (apptId != null) {
        await _db.from('crm_entries').insert({
          'user_id': userId,
          'type': 'appointment',
          'title': title,
          'amount': 0,
          'date': DateTime.now().toIso8601String(),
          'status': 'pending',
          'customer_name': customerName,
          'customer_phone': customerPhone,
        });
      }

      return apptId;
    } catch (_) {
      return null;
    }
  }

  /// Belirli bir tarihteki randevuları getir.
  static Future<List<Appointment>> getAppointmentsForDate(
      DateTime date) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final dateStr = date.toIso8601String().split('T').first;

      final result = await _db
          .from('appointments')
          .select('''
            *,
            attendee:users!appointments_attendee_id_fkey(full_name)
          ''')
          .eq('date', dateStr)
          .or('created_by.eq.$userId,attendee_id.eq.$userId')
          .order('start_time', ascending: true);

      return (result as List).map((j) {
        final map = j as Map<String, dynamic>;
        final attendee = map['attendee'] as Map<String, dynamic>?;
        return Appointment.fromJson({
          ...map,
          'attendee_name': attendee?['full_name'] ?? '',
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── ARAMA ───

  /// Müşteri adına göre tüm randevuları ara (geçmiş dahil).
  static Future<List<Appointment>> searchAppointments(
      String query) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final result = await _db
          .from('appointments')
          .select('''
            *,
            attendee:users!appointments_attendee_id_fkey(full_name)
          ''')
          .or('created_by.eq.$userId,attendee_id.eq.$userId')
          .ilike('title', '%$query%')
          .order('date', ascending: false)
          .order('start_time', ascending: false)
          .limit(100);

      return (result as List).map((j) {
        final map = j as Map<String, dynamic>;
        final attendee = map['attendee'] as Map<String, dynamic>?;
        return Appointment.fromJson({
          ...map,
          'attendee_name': attendee?['full_name'] ?? '',
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Çalışan adına göre tüm görevleri ara (geçmiş dahil).
  static Future<List<TaskItem>> searchTasksByAssignee(
      String query) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      // Önce assignee adıyla eşleşen kullanıcıları bul
      final users = await _db
          .from('users')
          .select('id')
          .ilike('full_name', '%$query%');

      if (users.isEmpty) return [];

      final userIds =
          (users as List).map((u) => (u as Map)['id'] as String).toList();

      // O kullanıcıların oluşturduğu veya atandığı görevleri çek
      final orParts = <String>[
        'created_by.in.(${userIds.join(',')})',
        'assigned_to.in.(${userIds.join(',')})',
      ];
      // Kendi görevlerimi de ekle
      orParts.add('created_by.eq.$userId');
      orParts.add('assigned_to.eq.$userId');

      final result = await _db
          .from('tasks')
          .select('''
            *,
            creator:users!tasks_created_by_fkey(full_name),
            assignee:users!tasks_assigned_to_fkey(full_name)
          ''')
          .or(orParts.join(','))
          .order('created_at', ascending: false)
          .limit(200);

      return (result as List).map((j) {
        final map = j as Map<String, dynamic>;
        final creator = map['creator'] as Map<String, dynamic>?;
        final assignee = map['assignee'] as Map<String, dynamic>?;
        return TaskItem.fromJson({
          ...map,
          'creator_name': creator?['full_name'] ?? '',
          'assignee_name': assignee?['full_name'] ?? '',
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── ARKADAŞLAR (görev atama için) ───

  /// Bir kişinin etiketlenebilir olup olmadığını kontrol et.
  /// Kişi işletme grubunda OLMALI VE işletmeyi takip ETMELİ.
  /// [targetUserId] `users.id` olmalı (auth id değil).
  static Future<bool> canTagUser({
    required String targetUserId,
    required String groupId,
  }) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return false;

      // 1. Kişi işletme grubunda mı?
      final groupMember = await _db
          .from('group_members')
          .select('id')
          .eq('user_id', targetUserId)
          .eq('group_id', groupId)
          .maybeSingle();
      if (groupMember == null) return false;

      // 2. Kişi işletmeyi takip ediyor mu?
      final followRow = await _db
          .from('followers')
          .select('id')
          .eq('follower_id', targetUserId)
          .eq('following_id', myId)
          .maybeSingle();
      if (followRow == null) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcının kabul edilmiş connections listesini getir.
  static Future<List<Map<String, dynamic>>> getMyConnections() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final result = await _db
          .from('connections')
          .select('''
            id, status, role,
            connected:users!connections_connected_id_fkey(id, full_name, username, avatar_url)
          ''')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
