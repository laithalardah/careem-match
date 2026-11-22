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

class T {
  /// Editorial serif for headings.
  static TextStyle display(double size, {FontStyle style = FontStyle.normal}) => GoogleFonts.newsreader(
        fontSize: size,
        fontWeight: FontWeight.w500,
        fontStyle: style,
        height: 1.1,
        letterSpacing: -0.03 * size,
        color: Tok.ink,
      );

  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color color = Tok.ink}) =>
      GoogleFonts.geist(fontSize: size, fontWeight: weight, height: 1.5, color: color);

  static TextStyle secondary({double size = 15}) => body(size: size, color: Tok.secondary);

  static TextStyle mono({double size = 12, Color color = Tok.secondary}) =>
      GoogleFonts.geistMono(fontSize: size, height: 1.5, color: color);

  /// Tiny uppercase tag text.
  static TextStyle tag(Color color) =>
      GoogleFonts.geist(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.55, height: 1.2, color: color);
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
