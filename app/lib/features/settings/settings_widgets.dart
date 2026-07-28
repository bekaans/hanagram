// Hanagram — ayarlar yardımcı widget'ları

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import 'settings_provider.dart';

// ─── Bölüm ───

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: c.violet),
            const SizedBox(width: HgSpace.sm),
            Text(title,
                style: HgText.caption.copyWith(
                    color: c.textMuted, letterSpacing: 0.5, shadows: null)),
          ],
        ),
        const SizedBox(height: HgSpace.sm),
        SettingsGlassCard(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 0.5, color: c.border.withValues(alpha: 0.5)),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Cam kart ───

class SettingsGlassCard extends StatelessWidget {
  const SettingsGlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(HgRadius.md),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
      ),
      child: child,
    );
  }
}

// ─── Tema seçici ───

class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.settings});
  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(HgSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema', style: HgText.bodyStrong.copyWith(color: c.text, shadows: null)),
          const SizedBox(height: HgSpace.md),
          Row(
            children: [
              ThemeOption(
                icon: CupertinoIcons.circle_lefthalf_fill,
                label: 'Otomatik',
                selected: settings.themeMode == 'system',
                onTap: () => settings.setThemeMode('system'),
              ),
              const SizedBox(width: HgSpace.sm),
              ThemeOption(
                icon: CupertinoIcons.sun_max,
                label: 'Açık',
                selected: settings.themeMode == 'light',
                onTap: () => settings.setThemeMode('light'),
              ),
              const SizedBox(width: HgSpace.sm),
              ThemeOption(
                icon: CupertinoIcons.moon,
                label: 'Koyu',
                selected: settings.themeMode == 'dark',
                onTap: () => settings.setThemeMode('dark'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ThemeOption extends StatelessWidget {
  const ThemeOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: HgSpace.md),
          decoration: BoxDecoration(
            color: selected ? c.violet.withValues(alpha: 0.15) : c.surfaceAlt.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(HgRadius.md),
            border: Border.all(
              color: selected ? c.violet : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? c.violet : c.textMuted),
              const SizedBox(height: HgSpace.xs),
              Text(label,
                  style: HgText.caption.copyWith(
                    color: selected ? c.violet : c.textMuted,
                    shadows: null,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Toggle satırı ───

class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: HgSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: HgText.body.copyWith(color: c.text, shadows: null)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: HgText.small.copyWith(color: c.textFaint, shadows: null)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: c.violet,
          ),
        ],
      ),
    );
  }
}

// ─── Bilgi satırı ───

class SettingsInfoTile extends StatelessWidget {
  const SettingsInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: HgSpace.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: HgSpace.md),
          Text(label, style: HgText.body.copyWith(color: c.text, shadows: null)),
          const Spacer(),
          Text(value, style: HgText.small.copyWith(color: c.textMuted, shadows: null)),
        ],
      ),
    );
  }
}

// ─── Navigasyon satırı (tıklanabilir, sağda ok ikonu) ───

class SettingsNavigationTile extends StatelessWidget {
  const SettingsNavigationTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg, vertical: HgSpace.md),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.textMuted),
            const SizedBox(width: HgSpace.md),
            Text(label, style: HgText.body.copyWith(color: c.text, shadows: null)),
            const Spacer(),
            Text(
              value,
              style: HgText.small.copyWith(color: c.textFaint, shadows: null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: HgSpace.sm),
            Icon(CupertinoIcons.chevron_right, size: 14, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}
