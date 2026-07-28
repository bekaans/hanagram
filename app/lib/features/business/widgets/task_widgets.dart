// Hanagram — görev yönetimi yardımcı widget'ları

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../models/task_item.dart';
import 'task_models.dart';

// ─── Sekme butonu ───

class TaskTabBtn extends StatelessWidget {
  const TaskTabBtn({
    super.key,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    required this.c,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: active ? c.violet : Colors.transparent,
            width: 2,
          )),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: HgText.bodyStrong.copyWith(
              color: active ? c.violet : c.textMuted,
              shadows: null,
            )),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? c.violet.withValues(alpha: 0.15) : c.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: active ? c.violet : c.textMuted,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mini istatistik hücresi ───

class MiniStat extends StatelessWidget {
  const MiniStat({super.key, required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: color,
            fontFamily: '.SF Pro Text',
          )),
          const SizedBox(height: 2),
          Text(label, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
        ],
      ),
    );
  }
}

// ─── Görev kartı ───

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.c, required this.onToggle});
  final TaskItem task;
  final HgColors c;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final priorityColor = task.priority == TaskPriority.high
        ? c.coral
        : task.priority == TaskPriority.medium ? c.blue : c.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: HgSpace.sm),
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isDone ? c.success : Colors.transparent,
                border: Border.all(
                  color: task.isDone ? c.success : c.textMuted,
                  width: 1.5,
                ),
              ),
              child: task.isDone
                  ? const Icon(CupertinoIcons.checkmark, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: HgText.bodyStrong.copyWith(
                  color: task.isDone ? c.textMuted : c.text,
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                  shadows: null,
                )),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(CupertinoIcons.person, size: 11, color: c.textFaint),
                    const SizedBox(width: 3),
                    Text(task.assignee, style: HgText.caption.copyWith(color: c.textFaint, shadows: null)),
                    const SizedBox(width: HgSpace.md),
                    Icon(CupertinoIcons.clock, size: 11, color: c.textFaint),
                    const SizedBox(width: 3),
                    Text(task.time, style: HgText.caption.copyWith(color: c.textFaint, shadows: null)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(task.priorityLabel, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: priorityColor,
            )),
          ),
        ],
      ),
    );
  }
}

// ─── Çalışan kartı ───

class WorkerCard extends StatelessWidget {
  const WorkerCard({super.key, required this.worker, required this.c, required this.onRemove});
  final Worker worker;
  final HgColors c;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isActive = worker.status == 'Aktif';
    return Container(
      margin: const EdgeInsets.only(bottom: HgSpace.sm),
      padding: const EdgeInsets.all(HgSpace.md),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isActive
                  ? [c.violet, c.blue]
                  : [c.textMuted, c.textFaint]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(worker.avatar, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
              )),
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name, style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
                Text(worker.role, style: HgText.caption.copyWith(color: c.textMuted, shadows: null)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? c.success.withValues(alpha: 0.12) : c.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(worker.status, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isActive ? c.success : c.warning,
            )),
          ),
        ],
      ),
    );
  }
}
