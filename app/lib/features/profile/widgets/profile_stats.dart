// Hanagram — profil istatistik satırı (Supabase)
//
// Canlı veri: randevu/satış sayısı, toplam müşteri, hızlı yanıt rozeti.
// Sadece rakam gösterilir, tıklanmaz.
// Gizlilik: bağlantı yoksa "Gizli" gösterilir.
import 'package:flutter/widgets.dart';

import 'package:hanagram_design/design.dart';
import '../../../core/profile_service.dart';

class ProfileStats extends StatefulWidget {
  const ProfileStats({
    super.key,
    required this.targetAuthId,
    required this.isOwner,
    this.isGranted = false,
  });

  final String targetAuthId;
  final bool isOwner;
  final bool isGranted;

  @override
  State<ProfileStats> createState() => _ProfileStatsState();
}

class _ProfileStatsState extends State<ProfileStats> {
  ProfileStatsData? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant ProfileStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetAuthId != widget.targetAuthId) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    if (widget.targetAuthId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final stats = await ProfileService.getProfileStats(widget.targetAuthId);
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final canSee = widget.isOwner || widget.isGranted;

    if (_loading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (i) => _loadingCell(c)),
      );
    }

    final stats = _stats ?? const ProfileStatsData();
    final primaryLabel = stats.primaryLabel;
    final primaryCount = stats.primaryCount;
    final customerCount = stats.totalCustomers;
    final hasBadge = stats.isFastResponder;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statCell(c, '$primaryCount', primaryLabel, canSee),
            _statCell(c, '$customerCount', 'Müşteri', canSee),
            _statCell(c, stats.phone.isNotEmpty ? '📞' : '—', 'İletişim', true),
          ],
        ),
        if (hasBadge) ...[
          const SizedBox(height: HgSpace.md),
          _fastResponseBadge(c, stats),
        ],
      ],
    );
  }

  Widget _statCell(HgColors c, String value, String label, bool visible) {
    return Column(
      children: [
        Text(
          visible ? value : '•••',
          style: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c.text,
            shadows: HgShadow.forTheme(c),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: HgText.caption
              .copyWith(color: c.textMuted, shadows: null),
        ),
      ],
    );
  }

  Widget _loadingCell(HgColors c) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 22,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 10,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _fastResponseBadge(HgColors c, ProfileStatsData stats) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: HgSpace.md, vertical: HgSpace.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.success.withValues(alpha: 0.12),
            c.violet.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(HgRadius.pill),
        border: Border.all(
          color: c.success.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: HgSpace.sm),
          Flexible(
            child: Text(
              stats.fastResponderMessage,
              style: HgText.small.copyWith(
                color: c.success,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
