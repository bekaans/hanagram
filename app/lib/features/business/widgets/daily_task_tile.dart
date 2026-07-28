// Hanagram — günlük görev kartı
//
// Panel akışında tek bir görev satırı.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../models/task_item.dart';

/// Tek bir görev satırı — onay kutucuğu, başlık, saat, öncelik, sorumlu.
class DailyTaskTile extends StatelessWidget {
  const DailyTaskTile({
    super.key,
    required this.task,
    required this.c,
    this.onToggle,
  });

  final TaskItem task;
  final HgColors c;
  final ValueChanged<bool>? onToggle;

  Color get _priorityColor {
    switch (task.priority) {
      case TaskPriority.high:
        return const Color(0xFFFF5A65);
      case TaskPriority.medium:
        return const Color(0xFFFFB020);
      case TaskPriority.low:
        return const Color(0xFF3DD68C);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: HgSpace.sm),
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Onay kutucuğu
          GestureDetector(
            onTap: onToggle != null ? () => onToggle!(!task.isDone) : null,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: task.isDone ? c.violet.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.isDone ? c.violet : c.border,
                  width: task.isDone ? 0 : 1.5,
                ),
              ),
              child: task.isDone
                  ? Icon(Icons.check, size: 14, color: c.violet)
                  : null,
            ),
          ),
          const SizedBox(width: HgSpace.md),

          // Başlık + saat
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: HgText.bodyStrong.copyWith(
                    color: c.text,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(task.time,
                    style: HgText.caption.copyWith(color: c.textMuted)),
              ],
            ),
          ),

          // Öncelik etiketi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _priorityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(HgRadius.pill),
            ),
            child: Text(task.priorityLabel,
                style: HgText.caption.copyWith(color: _priorityColor)),
          ),

          // Sorumlu
          if (task.assignee.isNotEmpty) ...[
            const SizedBox(width: HgSpace.sm),
            CircleAvatar(
              radius: 12,
              backgroundColor: c.violet.withValues(alpha: 0.12),
              child: Text(
                task.assignee.isNotEmpty ? task.assignee[0] : '',
                style: TextStyle(fontSize: 10, color: c.violet, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
