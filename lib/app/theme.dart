import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Color tokens
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkChord = Color(0xFFFFD54F);
  static const Color _darkPrimary = Color(0xFFBB86FC);

  static const Color _lightBackground = Color(0xFFFAFAFA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightChord = Color(0xFF1565C0);
  static const Color _lightPrimary = Color(0xFF6200EE);

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.rubikTextTheme(base);
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.dark(
        primary: _darkPrimary,
        surface: _darkSurface,
        onPrimary: Colors.black,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: _buildTextTheme(base.textTheme),
      extensions: const [
        ChordBookColors(chordColor: _darkChord),
      ],
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.light(
        primary: _lightPrimary,
        surface: _lightSurface,
        onPrimary: Colors.white,
        onSurface: Colors.black,
      ),
      scaffoldBackgroundColor: _lightBackground,
      textTheme: _buildTextTheme(base.textTheme),
      extensions: const [
        ChordBookColors(chordColor: _lightChord),
      ],
    );
  }
}

/// Custom theme extension for chord-specific colors
@immutable
class ChordBookColors extends ThemeExtension<ChordBookColors> {
  const ChordBookColors({required this.chordColor});

  final Color chordColor;

  @override
  ChordBookColors copyWith({Color? chordColor}) {
    return ChordBookColors(chordColor: chordColor ?? this.chordColor);
  }

  @override
  ChordBookColors lerp(ChordBookColors? other, double t) {
    if (other == null) return this;
    return ChordBookColors(
      chordColor: Color.lerp(chordColor, other.chordColor, t)!,
    );
  }
}
