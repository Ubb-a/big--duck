import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class VaultRadii {
  static const double xs = 8;
  static const double tile = 14;
  static const double sm = 14;
  static const double md = 24;
  static const double card = 26;
  static const double dock = 28;
  static const double sheet = 32;
  static const double pill = 999;
}

class VaultSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double screenHorizontal = 20;
  static const double x6 = 24;
  static const double x8 = 32;
}

class AppPalette {
  final Color canvas;
  final Color radialGlow;
  final Color cardSolid;
  final Color glassFill;
  final Color glassElevatedFill;
  final Color glassBorder;
  final Color glassTopLeftBorder;
  final Color glassSpecular;
  final Color scrim;
  final Color ink;
  final Color secondary;
  final Color muted;
  final Color champagne;
  final Color champagneSoft;
  final Color primaryBtnFill;
  final Color primaryBtnInk;
  final Color invertedBtnFill;
  final Color invertedBtnInk;
  final Color signalGreen;
  final Color signalGreenSoft;
  final Color signalGreenInk;
  final Color coral;
  final Color coralSoft;
  final Color floodAmber;
  final Color floodSoft;
  final Color shadowColor;
  final bool isDark;

  const AppPalette({
    required this.canvas,
    required this.radialGlow,
    required this.cardSolid,
    required this.glassFill,
    required this.glassElevatedFill,
    required this.glassBorder,
    required this.glassTopLeftBorder,
    required this.glassSpecular,
    required this.scrim,
    required this.ink,
    required this.secondary,
    required this.muted,
    required this.champagne,
    required this.champagneSoft,
    required this.primaryBtnFill,
    required this.primaryBtnInk,
    required this.invertedBtnFill,
    required this.invertedBtnInk,
    required this.signalGreen,
    required this.signalGreenSoft,
    required this.signalGreenInk,
    required this.coral,
    required this.coralSoft,
    required this.floodAmber,
    required this.floodSoft,
    required this.shadowColor,
    required this.isDark,
  });

  // Ergonomic aliases aligned to the Obsidian & Ivory Signal Vault tokens.
  Color get ground => canvas;
  Color get surface => cardSolid;
  Color get surfaceAlt => glassFill;
  Color get rule => glassBorder;
  Color get inkPrimary => ink;
  Color get inkSecondary => secondary;
  Color get inkMuted => muted;
  Color get danger => coral;
  Color get dangerSoft => coralSoft;
  Color get primary => primaryBtnFill;
  Color get primaryInk => primaryBtnInk;
  Color get emerald => signalGreen;
  Color get emeraldSoft => signalGreenSoft;

  /// Always returns deep black Obsidian Darkroom palette regardless of app theme.
  static AppPalette darkroom() => resolve(Brightness.dark);

  static AppPalette resolve(Brightness brightness) {
    if (brightness == Brightness.dark) {
      // Obsidian Luxury
      return const AppPalette(
        canvas: Color(0xFF050506),
        radialGlow: Color(0xFF14151A),
        cardSolid: Color(0xFF1A1A1C),
        glassFill: Color(0x24787C87), // rgba(120,124,135,0.14)
        glassElevatedFill: Color(0x36787C87),
        glassBorder: Color(0x1FFFFFFF), // rgba(255,255,255,0.12)
        glassTopLeftBorder: Color(0x3DFFFFFF), // brighter top-left edge
        glassSpecular: Color(0x33FFFFFF), // top specular sheen
        scrim: Color(0xB8050506), // WCAG AA backing over thumbnails/media
        ink: Color(0xFFF4F4F6),
        secondary: Color(0xFF9A9CA6),
        muted: Color(0xFF62646E),
        champagne: Color(0xFFD9D6CF),
        champagneSoft: Color(0x26D9D6CF),
        primaryBtnFill: Color(0xFFD9D6CF),
        primaryBtnInk: Color(0xFF050506),
        invertedBtnFill: Color(0xFFF4F4F6),
        invertedBtnInk: Color(0xFF050506),
        signalGreen: Color(0xFF4ADE80),
        signalGreenSoft: Color(0x244ADE80),
        signalGreenInk: Color(0xFF050506),
        coral: Color(0xFFF87171),
        coralSoft: Color(0x24F87171),
        floodAmber: Color(0xFFC9B27C),
        floodSoft: Color(0x24C9B27C),
        shadowColor: Color(0x80000000), // rgba(0,0,0,0.5)
        isDark: true,
      );
    }

    // Ivory Luxury
    return const AppPalette(
      canvas: Color(0xFFF7F6F3),
      radialGlow: Color(0xFFFFFFFF),
      cardSolid: Color(0xFFFFFFFF),
      glassFill: Color(0xA6FFFFFF), // rgba(255,255,255,0.65)
      glassElevatedFill: Color(0xD9FFFFFF),
      glassBorder: Color(0x0F000000), // rgba(0,0,0,0.06)
      glassTopLeftBorder: Color(0xE6FFFFFF), // delicate highlight
      glassSpecular: Color(0xF2FFFFFF),
      scrim: Color(0xD9F7F6F3), // frosted ivory scrim for WCAG AA over thumbs
      ink: Color(0xFF111114),
      secondary: Color(0xFF5E606A),
      muted: Color(0xFF9A9CA6),
      champagne: Color(0xFFB89B5E), // micro-details & gold focus accent
      champagneSoft: Color(0x1FB89B5E),
      primaryBtnFill: Color(0xFF17181C), // graphite primary CTA
      primaryBtnInk: Color(0xFFF7F6F3), // ivory text
      invertedBtnFill: Color(0xFFD9D6CF),
      invertedBtnInk: Color(0xFF111114),
      signalGreen: Color(0xFF16A34A), // darkened green for AA contrast on ivory
      signalGreenSoft: Color(0x1F16A34A),
      signalGreenInk: Color(0xFFF7F6F3),
      coral: Color(0xFFDC2626), // high-contrast coral-red on light
      coralSoft: Color(0x1AF87171),
      floodAmber: Color(0xFF8C6D32),
      floodSoft: Color(0x26C9B27C),
      shadowColor: Color(0x1414141E), // rgba(20,20,30,0.08)
      isDark: false,
    );
  }
}

class VaultText {
  static final RegExp _arabicChars = RegExp(r'[\u0600-\u06FF]');

  static bool containsArabic(String text) => _arabicChars.hasMatch(text);

  static String fontFamily(bool isArabic) =>
      isArabic ? 'IBMPlexSansArabic' : 'IBMPlexSans';

  static TextStyle display(
    AppPalette p,
    bool isArabic, {
    double size = 34,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        fontFamilyFallback: const ['IBMPlexSansArabic', 'IBMPlexSans'],
        color: color ?? p.ink,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: isArabic ? 0 : (size >= 30 ? -0.8 : -0.45),
        height: isArabic ? 1.3 : 1.15,
      );

  static TextStyle heading(
    AppPalette p,
    bool isArabic, {
    double size = 22,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        fontFamilyFallback: const ['IBMPlexSansArabic', 'IBMPlexSans'],
        color: color ?? p.ink,
        fontSize: isArabic ? size + 1 : size,
        fontWeight: weight,
        letterSpacing: isArabic ? 0 : -0.25,
        height: isArabic ? 1.45 : 1.25,
      );

  static TextStyle body(
    AppPalette p,
    bool isArabic, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    bool applyArabicScale = true,
  }) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        fontFamilyFallback: const ['IBMPlexSansArabic', 'IBMPlexSans'],
        color: color ?? p.ink,
        fontSize: (isArabic && applyArabicScale) ? size + 1 : size,
        fontWeight: weight,
        letterSpacing: 0,
        height: isArabic ? 1.6 : 1.45,
      );

  static TextStyle tabular(
    AppPalette p,
    bool isArabic, {
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        fontFamilyFallback: const ['IBMPlexSansArabic', 'IBMPlexSans'],
        color: color ?? p.secondary,
        fontSize: size,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: isArabic ? 1.5 : 1.35,
      );

  /// Technical label / metadata typography (IBM Plex Mono, +8% tracking on ASCII).
  /// Never breaks cursive Arabic glyphs if an Arabic phrase is rendered alongside data.
  static TextStyle mono(
    AppPalette p, {
    double size = 11.5,
    Color? color,
    FontWeight weight = FontWeight.w400,
    bool hasArabic = false,
  }) =>
      TextStyle(
        fontFamily: 'IBMPlexMono',
        fontFamilyFallback: const ['IBMPlexSansArabic'],
        color: color ?? p.secondary,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: hasArabic ? 0 : size * 0.08,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: hasArabic ? 1.55 : 1.35,
      );

  static TextStyle monoText(
    AppPalette p,
    String text, {
    double size = 11.5,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) =>
      mono(
        p,
        size: size,
        color: color,
        weight: weight,
        hasArabic: containsArabic(text),
      );
}

/// Canonical Signal Vault motion token table (durations, curves, distances, stagger, RTL, reduce-motion).
class VaultMotionTokens {
  const VaultMotionTokens();

  // Durations
  final Duration instant = const Duration(milliseconds: 90);
  final Duration reducedFade = const Duration(milliseconds: 150);
  final Duration fast = const Duration(milliseconds: 180);
  final Duration base = const Duration(milliseconds: 250);
  final Duration slow = const Duration(milliseconds: 400);
  final Duration ambient = const Duration(milliseconds: 4000);
  final Duration staggerStep = const Duration(milliseconds: 30);
  final int maxStaggerItems = 8;

  // Curves
  final Curve standard = const Cubic(0.2, 0.0, 0.0, 1.0);
  final Curve emphasized = const Cubic(0.16, 1.0, 0.3, 1.0);
  final Curve exit = const Cubic(0.4, 0.0, 1.0, 1.0);
  final Curve linear = Curves.linear;

  // Distances (logical px)
  final double shiftSmall = 8.0;
  final double shiftMedium = 16.0;
  final double shiftPage = 24.0;

  bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Callable helper matching legacy `vaultMotion(context, ms)` call sites while respecting Reduce Motion.
  Duration call(BuildContext context, [int milliseconds = 250]) {
    if (isReduced(context)) return reducedFade;
    return Duration(milliseconds: milliseconds);
  }

  /// Resolves a motion token duration with clean 150ms fade fallback when Reduce Motion is enabled.
  Duration duration(BuildContext context, Duration token) =>
      isReduced(context) ? reducedFade : token;

  /// Suppresses spatial shifts when Reduce Motion is active.
  Offset offset(BuildContext context, Offset normal) =>
      isReduced(context) ? Offset.zero : normal;

  /// Suppresses scaling transitions when Reduce Motion is active.
  double scale(BuildContext context, double normal) =>
      isReduced(context) ? 1.0 : normal;

  /// Mirrors horizontal slide delta in RTL (`TextDirection.rtl`).
  double directionalDx(BuildContext context, double dx) {
    if (isReduced(context)) return 0.0;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return rtl ? -dx : dx;
  }

  /// Controls whether ambient looping animations should tick.
  /// Stops all loops under Reduce Motion and avoids infinite ticker hangs during `flutter test`.
  bool allowLoops(BuildContext context, {bool forceInTest = false}) {
    if (isReduced(context)) return false;
    var inTest = false;
    assert(() {
      inTest = WidgetsBinding.instance.runtimeType
          .toString()
          .contains('TestWidgets');
      return true;
    }());
    if (inTest && !forceInTest) return false;
    return true;
  }

  Interval staggerInterval(int index, {int stepMs = 30, int totalMs = 450}) {
    final capped = index.clamp(0, maxStaggerItems);
    final start = ((capped * stepMs) / totalMs).clamp(0.0, 0.72);
    final end = (start + 0.55).clamp(0.0, 1.0);
    return Interval(start, end, curve: standard);
  }
}

const vaultMotion = VaultMotionTokens();

class VaultHaptics {
  static void light() => HapticFeedback.lightImpact();
  static void selection() => HapticFeedback.selectionClick();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.lightImpact();
  static void error() => HapticFeedback.vibrate();
}
