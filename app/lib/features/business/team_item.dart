// Hanagram — team data models
//
// Domain models for Arkadram team management system.
// No business logic — pure data carriers.

class TeamMember {
  const TeamMember({
    required this.name,
    this.role = 'Üye',
  });

  final String name;
  final String role;

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

List<TeamItem> sampleTeams() {
  return [
    TeamItem(
      id: 't1',
      name: 'Han Medya Ekip',
      members: [
        const TeamMember(name: 'Kaan', role: 'Yönetici'),
        const TeamMember(name: 'Elif Yılmaz'),
        const TeamMember(name: 'Cenk Demir'),
      ],
      tasks: [
        const SharedTask(title: 'Instagram içerik planı', assignee: 'Elif', isDone: true),
        const SharedTask(title: 'Reels senaryoları yaz', assignee: 'Kaan'),
        const SharedTask(title: 'Logo revizyonu gönder', assignee: 'Cenk'),
      ],
      crmEntries: [
        const CrmEntry(clientName: 'Studio Nova', note: 'Fotoğraf çekimi randevusu'),
        const CrmEntry(clientName: 'Dr. Ahmet Kaya', note: 'Reklam kampanyası başladı'),
      ],
    ),
    TeamItem(
      id: 't2',
      name: 'Grafik Ekibi',
      members: [
        const TeamMember(name: 'Ayşe Kaya', role: 'Yönetici'),
        const TeamMember(name: 'Mehmet Arslan'),
      ],
      tasks: [
        const SharedTask(title: 'Broşür tasarımı', assignee: 'Ayşe'),
        const SharedTask(title: 'Sosyal medya şablonları', assignee: 'Mehmet'),
      ],
      crmEntries: [
        const CrmEntry(clientName: 'Zeynep Arslan', note: 'Kartvizit tasarımı'),
      ],
    ),
  ];
}
