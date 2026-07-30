// Hanagram — team data models
//
// Domain models for Arkadram team management system.
// No business logic — pure data carriers.

class TeamMember {
  const TeamMember({
    required this.name,
    this.role = 'Üye',
    this.userId = '',
  });

  final String name;
  final String role;
  final String userId;

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}';
    return name.substring(0, name.length.clamp(0, 2));
  }
}

class SharedTask {
  const SharedTask({
    required this.title,
    this.assignee,
    this.isDone = false,
  });

  final String title;
  final String? assignee;
  final bool isDone;
}

class CrmEntry {
  const CrmEntry({
    required this.clientName,
    required this.note,
  });

  final String clientName;
  final String note;
}

class TeamItem {
  const TeamItem({
    required this.id,
    required this.name,
    required this.members,
    this.tasks = const [],
    this.crmEntries = const [],
  });

  final String id;
  final String name;
  final List<TeamMember> members;
  final List<SharedTask> tasks;
  final List<CrmEntry> crmEntries;
}
