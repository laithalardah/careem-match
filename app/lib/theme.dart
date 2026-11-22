import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens: Careem forest green, bright mint, crisp white/mint-wash sheets, 1px borders.
class Tok {
  static const careemDark = Color(0xFF0A271E);
  static const careemGreen = Color(0xFF154E3B);
  static const careemMid = Color(0xFF1D6A50);
  static const careemMint = Color(0xFF6FE89F);
  static const careemMintWash = Color(0xFFECF8F1);

  static const canvas = Color(0xFFF6FBF8);
  static const card = Color(0xFFFFFFFF);
  static const wash = Color(0xFFF0F7F3);
  static const border = Color(0xFFDFECE5);
  static const ink = Color(0xFF0E2A20);
  static const inkPressed = Color(0xFF1B5240);
  static const secondary = Color(0xFF536C62); // 4.5:1+ on canvas

  // Spacing scale (4/8/12/16/24/32)
  static const s4 = 4.0, s8 = 8.0, s12 = 12.0, s16 = 16.0, s24 = 24.0, s32 = 32.0, s48 = 48.0;

  static const radius = 12.0; // cards
  static const radiusSm = 8.0; // buttons

  /// Desaturated pastel pairs: (background, text).
  static const red = (Color(0xFFFDEBEC), Color(0xFF9F2F2D));
  static const blue = (Color(0xFFE3F4F1), Color(0xFF14594B));
  static const green = (Color(0xFFE6F7ED), Color(0xFF13563B));
  static const yellow = (Color(0xFFFBF3DB), Color(0xFF956400));

  static const maxWidth = 480.0;
}

/// Type matches the Careem home page: one face (Geist) everywhere, bold and extra-bold for headlines.
/// (The home page's own biggest headline is 22 pt extra-bold; sizes below are scaled to sit in that range.)
class T {
  /// Headlines: same face and weight as the home page ("AED 500 off across 10 orders").
  /// The `size` argument is the old design size; it is scaled so bold sans headlines are not oversized.
  static TextStyle display(double size, {FontStyle style = FontStyle.normal}) {
    final s = size * 0.72;
    return GoogleFonts.geist(
      fontSize: s,
      fontWeight: s >= 20 ? FontWeight.w800 : FontWeight.w700,
      height: 1.16,
      letterSpacing: -0.02 * s,
      color: Tok.ink,
    );
  }

  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color color = Tok.ink}) =>
      GoogleFonts.geist(fontSize: size, fontWeight: weight, height: 1.5, color: color);

  static TextStyle secondary({double size = 15}) => body(size: size, color: Tok.secondary);

  /// Numbers, counters and room codes: the same face with aligned digits (the home page has no monospace).
  static TextStyle mono({double size = 12, Color color = Tok.secondary}) => GoogleFonts.geist(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.2,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Small badge text, as the home page's "New" and discount badges (bold, tight).
  static TextStyle tag(Color color) =>
      GoogleFonts.geist(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, height: 1.2, color: color);
}

ThemeData buildTheme() {
  final scheme = const ColorScheme.light().copyWith(
    primary: Tok.ink,
    onPrimary: Colors.white,
    surface: Tok.canvas,
    onSurface: Tok.ink,
    outline: Tok.border,
    secondary: Tok.secondary,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tok.canvas,
    splashFactory: NoSplash.splashFactory,
    textTheme: GoogleFonts.geistTextTheme(),
    dividerTheme: const DividerThemeData(color: Tok.border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Tok.careemGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.radiusSm)),
        textStyle: T.body(weight: FontWeight.w600),
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed) ? Tok.careemDark.withValues(alpha: 0.35) : null,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Tok.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Tok.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.radiusSm)),
        textStyle: T.body(weight: FontWeight.w600),
      ),
    ),
  );
}
