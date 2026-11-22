import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens: warm monochrome, 1px borders, near-invisible shadows, pastel accents only for tags.
class Tok {
  static const canvas = Color(0xFFFBFBFA);
  static const card = Color(0xFFFFFFFF);
  static const wash = Color(0xFFF7F6F3);
  static const border = Color(0xFFEAEAEA);
  static const ink = Color(0xFF111111);
  static const inkPressed = Color(0xFF333333);
  static const secondary = Color(0xFF787774); // 4.5:1+ on canvas

  // Spacing scale (4/8/12/16/24/32)
  static const s4 = 4.0, s8 = 8.0, s12 = 12.0, s16 = 16.0, s24 = 24.0, s32 = 32.0, s48 = 48.0;

  static const radius = 10.0; // cards
  static const radiusSm = 6.0; // buttons

  /// Desaturated pastel pairs: (background, text).
  static const red = (Color(0xFFFDEBEC), Color(0xFF9F2F2D));
  static const blue = (Color(0xFFE1F3FE), Color(0xFF1F6C9F));
  static const green = (Color(0xFFEDF3EC), Color(0xFF346538));
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
        backgroundColor: Tok.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.radiusSm)),
        textStyle: T.body(weight: FontWeight.w600),
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.pressed) ? Tok.inkPressed.withValues(alpha: 0.5) : null,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Tok.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Tok.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tok.radiusSm)),
        textStyle: T.body(weight: FontWeight.w600),
      ),
    ),
  );
}
