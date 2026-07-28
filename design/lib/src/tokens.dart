// Hanagram — tasarım belirteçleri
//
// Apple SF font, liquid glass, koyu tonlar, 3D gölgeli font şeması.
import 'package:flutter/material.dart';

/// Apple SF font ailesi — tüm platformlarda natural görünür.
const String _sfFont = '.SF Pro Text';

class HgColors {
  const HgColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.coral,
    required this.violet,
    required this.blue,
    required this.success,
    required this.warning,
    required this.danger,
    required this.onBrand,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textFaint;

  // Marka üçlüsü
  final Color coral;
  final Color violet;
  final Color blue;

  final Color success;
  final Color warning;
  final Color danger;
  final Color onBrand;

  /// Tema ayırt etme: açık tema mı?
  bool get isLight => this == HgColors.light;

  /// Marka gradyanı: logodaki halkanın renkleri.
  LinearGradient get brand => LinearGradient(
        colors: [coral, violet, blue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color get accent => violet;

  /// Koyu tema — daha derin, daha liquid.
  static const dark = HgColors(
    bg: Color(0xFF05030A),        // çok koyu mor-siyah
    surface: Color(0xFF0D0A14),   // hafif açık
    surfaceAlt: Color(0xFF15101E), // input, card arkaplanı
    border: Color(0xFF221C30),    // ince çizgiler
    text: Color(0xFFF8F6FC),      // neredeyse beyaz
    textMuted: Color(0xFFB8B0CC), // orta gri-mor
    textFaint: Color(0xFF6B6280), // soluk
    coral: Color(0xFFF0485E),
    violet: Color(0xFFA855F7),
    blue: Color(0xFF5B7CFA),
    success: Color(0xFF3DD68C),
    warning: Color(0xFFFFB020),
    danger: Color(0xFFFF5A65),
    onBrand: Color(0xFFFFFFFF),
  );

  static const light = HgColors(
    bg: Color(0xFFF7F5FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0EDF6),
    border: Color(0xFFE2DEEC),
    text: Color(0xFF17131F),
    textMuted: Color(0xFF5F5872),
    textFaint: Color(0xFF938BA6),
    coral: Color(0xFFE0324A),
    violet: Color(0xFF8B36E0),
    blue: Color(0xFF3A5FE0),
    success: Color(0xFF10A46A),
    warning: Color(0xFFB87400),
    danger: Color(0xFFD32F3C),
    onBrand: Color(0xFFFFFFFF),
  );
}

/// Boşluk ölçeği — 4'ün katları.
class HgSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  static const double bottomNavHeight = 88;
  static const double bottomRailHeight = 16;

  static double bottomPadding(BuildContext context) =>
      HgBreak.isPhone(context) ? bottomNavHeight : bottomRailHeight;
}

class HgRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 26;
  static const double pill = 999;
}

/// 3D gölge efekti — temaya göre adapte olur.
class HgShadow {
  /// Koyu tema için hafif 3D — kartlar, butonlar için.
  static List<Shadow> get subtle => const [
    Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Koyu tema için orta 3D — başlıklar için.
  static List<Shadow> get medium => const [
    Shadow(color: Color(0x60000000), blurRadius: 12, offset: Offset(0, 3)),
  ];

  /// Koyu tema için güçlü 3D — display, hero text için.
  static List<Shadow> get strong => const [
    Shadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 4)),
    Shadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 8)),
  ];

  /// Temaya göre gölge döndür — açık temada gölge yok, koyu temada mevcut gölgeler.
  static List<Shadow> forTheme(HgColors c) {
    if (c.isLight) return const [];
    return subtle;
  }

  /// Temaya göre orta gölge.
  static List<Shadow> mediumForTheme(HgColors c) {
    if (c.isLight) return const [];
    return medium;
  }

  /// Temaya göre güçlü gölge.
  static List<Shadow> strongForTheme(HgColors c) {
    if (c.isLight) return const [];
    return strong;
  }
}

/// Tipografi ölçeği — Apple SF Font.
/// Not: Renk ve gölge HgText temel stillerinde tanımlıdır.
/// Widget'larda `.copyWith(color: c.text, shadows: HgShadow.forTheme(c))` ile
/// temaya göre override edilmelidir.
class HgText {
  static const display = TextStyle(
    fontFamily: _sfFont,
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: Color(0xFFF8F6FC),
    shadows: [
      Shadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 4)),
      Shadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 8)),
    ],
  );

  static const title = TextStyle(
    fontFamily: _sfFont,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: Color(0xFFF8F6FC),
    shadows: [
      Shadow(color: Color(0x60000000), blurRadius: 10, offset: Offset(0, 2)),
    ],
  );

  static const heading = TextStyle(
    fontFamily: _sfFont,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: Color(0xFFF8F6FC),
    shadows: [
      Shadow(color: Color(0x50000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  static const body = TextStyle(
    fontFamily: _sfFont,
    fontSize: 15,
    height: 1.45,
    color: Color(0xFFF0EDF4),
    shadows: [
      Shadow(color: Color(0x30000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
  );

  static const bodyStrong = TextStyle(
    fontFamily: _sfFont,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
    color: Color(0xFFF8F6FC),
    shadows: [
      Shadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 1)),
    ],
  );

  static const small = TextStyle(
    fontFamily: _sfFont,
    fontSize: 13,
    height: 1.4,
    color: Color(0xFFD8D2E4),
  );

  static const caption = TextStyle(
    fontFamily: _sfFont,
    fontSize: 11.5,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: Color(0xFF9890AC),
  );

  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 15,
    height: 1.4,
    letterSpacing: 3,
    fontWeight: FontWeight.w700,
  );

  // ─── Temaya göre resolved stiller ───

  /// Tema rengi ve gölgesi ile resolve edilmiş display stili.
  static TextStyle displayResolved(HgColors c) => display.copyWith(
    color: c.text,
    shadows: HgShadow.strongForTheme(c),
  );

  /// Tema rengi ve gölgesi ile resolve edilmiş title stili.
  static TextStyle titleResolved(HgColors c) => title.copyWith(
    color: c.text,
    shadows: HgShadow.mediumForTheme(c),
  );

  /// Tema rengi ve gölgesi ile resolve edilmiş heading stili.
  static TextStyle headingResolved(HgColors c) => heading.copyWith(
    color: c.text,
    shadows: HgShadow.forTheme(c),
  );

  /// Tema rengi ve gölgesi ile resolve edilmiş body stili.
  static TextStyle bodyResolved(HgColors c) => body.copyWith(
    color: c.text,
    shadows: HgShadow.forTheme(c),
  );

  /// Tema rengi ve gölgesi ile resolve edilmiş bodyStrong stili.
  static TextStyle bodyStrongResolved(HgColors c) => bodyStrong.copyWith(
    color: c.text,
    shadows: HgShadow.forTheme(c),
  );

  /// Tema rengi ile resolve edilmiş small stili.
  static TextStyle smallResolved(HgColors c) => small.copyWith(
    color: c.textMuted,
  );

  /// Tema rengi ile resolve edilmiş caption stili.
  static TextStyle captionResolved(HgColors c) => caption.copyWith(
    color: c.textMuted,
  );

  /// Ekran genişliğine göre ölçeklendirilmiş TextStyle.
  static TextStyle scale(BuildContext context, TextStyle base) {
    final w = MediaQuery.sizeOf(context).width;
    final factor = w >= HgBreak.desktop ? 1.12 : w >= HgBreak.tablet ? 1.05 : 1.0;
    return base.copyWith(fontSize: base.fontSize != null ? base.fontSize! * factor : null);
  }
}

class HgMotion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}

/// Uyarlanabilir yerleşim eşikleri.
class HgBreak {
  static const double tablet = 700;
  static const double desktop = 1100;

  static bool isPhone(BuildContext c) => MediaQuery.sizeOf(c).width < tablet;
  static bool isTablet(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= tablet && w < desktop;
  }

  static bool isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= desktop;
}

/// Renkleri widget ağacına taşır.
class HgTheme extends InheritedWidget {
  const HgTheme({super.key, required this.colors, required super.child});

  final HgColors colors;

  static HgColors of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<HgTheme>();
    return t?.colors ?? HgColors.dark;
  }

  @override
  bool updateShouldNotify(HgTheme oldWidget) => colors != oldWidget.colors;
}

ThemeData buildTheme(HgColors c, Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.bg,
    fontFamily: _sfFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.violet,
      brightness: brightness,
      surface: c.surface,
      primary: c.violet,
      onPrimary: c.onBrand,
      secondary: c.blue,
      error: c.danger,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: _sfFont,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: c.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HgRadius.md),
        side: BorderSide(color: c.border.withValues(alpha: 0.5)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? c.onBrand : c.textMuted),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? c.violet : c.surfaceAlt),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      hintStyle: TextStyle(color: c.textFaint, fontFamily: _sfFont),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HgRadius.md),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
