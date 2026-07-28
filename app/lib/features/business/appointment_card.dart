// Hanagram — randevu kartı: liste satırının modeli ve görünümü.
//
// appointment_screen.dart'tan ayrıldı (dosya 300 satırı aşıyordu). Model ve
// kart aynı yerde durur çünkü ikisi de yalnızca birbirleri için var.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/utils.dart';

class AppointmentItem {
  final String id;
  final String customerName;
  final String? phone;
  final String? service;
  final String? note;
  final int at;
  final int? priceKurus;
  final String status;
  final String? source;

  const AppointmentItem({
    required this.id,
    required this.customerName,
    this.phone,
    this.service,
    this.note,
    required this.at,
    this.priceKurus,
    required this.status,
    this.source,
  });

  factory AppointmentItem.fromJson(Map<String, dynamic> j) => AppointmentItem(
        id: j['id'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        phone: j['phone'] as String?,
        service: j['service'] as String?,
        note: j['note'] as String?,
        at: (j['at'] as num?)?.toInt() ?? 0,
        priceKurus: (j['priceKurus'] as num?)?.toInt(),
        status: j['status'] as String? ?? 'requested',
        source: j['source'] as String?,
      );
}

Color _statusColor(String status, HgColors c) {
  switch (status) {
    case 'requested':
      return c.warning;
    case 'confirmed':
      return c.blue;
    case 'completed':
      return c.success;
    case 'cancelled':
      return c.textFaint;
    default:
      return c.textMuted;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'requested':
      return 'Talep';
    case 'confirmed':
      return 'Onaylı';
    case 'completed':
      return 'Tamamlandı';
    case 'cancelled':
      return 'İptal';
    default:
      return status;
  }
}

/// Tek randevu satırı. `onAction(id, "confirmed"/"cancelled"/"completed")`
/// yalnızca durumu değiştirilebilir randevularda (requested/confirmed) çağrılır.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onAction,
  });

  final AppointmentItem appointment;
  final void Function(String id, String status) onAction;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final a = appointment;
    final statusColor = _statusColor(a.status, c);
    final canAct = a.status == 'requested' || a.status == 'confirmed';

    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(formatTimeFromMs(a.at), style: HgText.bodyStrong.copyWith(color: c.text)),
              const SizedBox(width: HgSpace.md),
              Expanded(
                child: Text(
                  a.customerName,
                  style: HgText.bodyStrong.copyWith(color: c.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              HgChip(label: _statusLabel(a.status), color: statusColor, filled: true),
            ],
          ),
          if (a.service != null && a.service!.isNotEmpty) ...[
            const SizedBox(height: HgSpace.xs),
            Text(a.service!, style: HgText.small.copyWith(color: c.textMuted)),
          ],
          if (canAct) ...[
            const SizedBox(height: HgSpace.sm),
            Row(
              children: [
                if (a.status == 'requested') ...[
                  _ActionButton(
                    label: 'Onayla',
                    color: c.success,
                    onTap: () => onAction(a.id, 'confirmed'),
                  ),
                  const SizedBox(width: HgSpace.sm),
                  _ActionButton(
                    label: 'Reddet',
                    color: c.danger,
                    onTap: () => onAction(a.id, 'cancelled'),
                  ),
                ] else if (a.status == 'confirmed') ...[
                  _ActionButton(
                    label: 'Tamamlandı',
                    color: c.success,
                    onTap: () => onAction(a.id, 'completed'),
                  ),
                  const SizedBox(width: HgSpace.sm),
                  _ActionButton(
                    label: 'İptal',
                    color: c.danger,
                    onTap: () => onAction(a.id, 'cancelled'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(HgRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(HgRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: HgText.caption.copyWith(color: color)),
        ),
      ),
    );
  }
}
