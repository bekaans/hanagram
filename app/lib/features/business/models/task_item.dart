// Hanagram — görev veri modeli

enum TaskPriority { low, medium, high }

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.time,
    required this.priority,
    this.isDone = false,
    this.assignee = '',
  });

  final String id;
  final String title;
  final String time;
  final TaskPriority priority;
  bool isDone;
  final String assignee;

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.high:
        return 'Yüksek';
      case TaskPriority.medium:
        return 'Normal';
      case TaskPriority.low:
        return 'Düşük';
    }
  }

  static final sampleTasks = [
    TaskItem(
      id: '1',
      title: 'Saç boyama - Elif Hanım',
      time: '14:00',
      priority: TaskPriority.high,
      assignee: 'Ayşe Yılmaz',
    ),
    TaskItem(
      id: '2',
      title: 'Manikür - Ayşe Hanım',
      time: '15:30',
      priority: TaskPriority.medium,
      assignee: 'Mehmet Kaya',
    ),
    TaskItem(
      id: '3',
      title: 'Makyaj prova - Düğün',
      time: '10:00',
      priority: TaskPriority.high,
      assignee: 'Zeynep Demir',
    ),
    TaskItem(
      id: '4',
      title: 'Stüdyo temizliği',
      time: '18:00',
      priority: TaskPriority.low,
      assignee: 'Mehmet Kaya',
      isDone: true,
    ),
  ];
}
