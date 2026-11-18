import 'package:material_ui/material_ui.dart';

class VaultRadii {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double dock = 18;
  static const double sheet = 20;
  static const double pill = 999;
}

class AppPalette {
  final Color ground;
  final Color surface;
  final Color surfaceAlt;
  final Color rule;
  final Color ink;
  final Color muted;
  final Color signal;
  final Color signalSoft;
  final Color signalInk;
  final Color cobalt;
  final Color cobaltSoft;
  final Color danger;
  final Color dangerSoft;
  final bool isDark;

  const AppPalette({
    required this.ground,
    required this.surface,
    required this.surfaceAlt,
    required this.rule,
    required this.ink,
    required this.muted,
    required this.signal,
    required this.signalSoft,
    required this.signalInk,
    required this.cobalt,
    required this.cobaltSoft,
    required this.danger,
    required this.dangerSoft,
    required this.isDark,
  });

  // Compatibility aliases kept coherent with the Signal Vault contract.
  Color get bgCanvas => ground;
  Color get bgSheet => surface;
  Color get bgElevated => surface;
  Color get bgInput => surfaceAlt;
  Color get bdHairline => rule;
  Color get inkPrimary => ink;
  Color get inkSecondary => muted;
  Color get inkMuted => muted;
  Color get accent => cobalt;
  Color get accentSoft => cobaltSoft;
  Color get accentInk => isDark ? const Color(0xFF0A0F18) : const Color(0xFFFFFFFF);
  Color get folder => cobalt;
  Color get seal => signal;

  static AppPalette resolve(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const AppPalette(
        ground: Color(0xFF0A0F18),
        surface: Color(0xFF121926),
        surfaceAlt: Color(0xFF1B2436),
        rule: Color(0xFF253045),
        ink: Color(0xFFF2F5FA),
        muted: Color(0xFF96A2B8),
        signal: Color(0xFFFFC400),
        signalSoft: Color(0x29FFC400),
        signalInk: Color(0xFF0A0F18),
        cobalt: Color(0xFF4DA3FF),
        cobaltSoft: Color(0x244DA3FF),
        danger: Color(0xFFFF6B4A),
        dangerSoft: Color(0x24FF6B4A),
        isDark: true,
      );
    }

    return const AppPalette(
      ground: Color(0xFFF4F5F7),
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFE9ECF1),
      rule: Color(0xFFD3D9E3),
      ink: Color(0xFF0B1220),
      muted: Color(0xFF525C6E),
      signal: Color(0xFFFFAE00),
      signalSoft: Color(0x26FFAE00),
      signalInk: Color(0xFF0B1220),
      cobalt: Color(0xFF005FE0),
      cobaltSoft: Color(0x1A005FE0),
      danger: Color(0xFFD93B00),
      dangerSoft: Color(0x1AD93B00),
      isDark: false,
    );
  }
}

class VaultText {
  static String fontFamily(bool isArabic) =>
      isArabic ? 'IBMPlexSansArabic' : 'IBMPlexSans';

  static TextStyle display(AppPalette p, bool isArabic, {double size = 26}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        color: p.ink,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: isArabic ? 0 : -0.6,
        height: 1.15,
      );

  static TextStyle heading(AppPalette p, bool isArabic, {double size = 16}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        color: p.ink,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: isArabic ? 0 : -0.2,
      );

  static TextStyle body(AppPalette p, bool isArabic,
          {double size = 14, FontWeight weight = FontWeight.w400, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        color: color ?? p.ink,
        fontSize: size,
        fontWeight: weight,
        height: 1.4,
      );

  static TextStyle tabular(AppPalette p, bool isArabic,
          {double size = 12.5, FontWeight weight = FontWeight.w600, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily(isArabic),
        color: color ?? p.muted,
        fontSize: size,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle mono(AppPalette p, {double size = 12, Color? color}) =>
      TextStyle(
        fontFamily: 'IBMPlexMono',
        color: color ?? p.muted,
        fontSize: size,
        height: 1.4,
      );
}

Duration vaultMotion(BuildContext context, int milliseconds) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return Duration.zero;
  }
  return Duration(milliseconds: milliseconds);
}
