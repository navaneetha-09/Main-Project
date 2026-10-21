import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Modern Clean Dark Slate Palette
  static const Color abyssNavy = Color(0xFF0B0F19); // Modern clean slate-950 background
  static const Color deepSeaCard = Color(0xFF131B2E); // Modern slate card surface
  static const Color oceanCardLight = Color(0xFF1B243B); // Elevated slate surface
  static const Color subseaBorder = Color(0x1AFFFFFF); // Subtle clean border
  static const Color subseaBorderLight = Color(0x2E38BDF8); // Subtle cyan border accent
  
  static const Color bioluminescentCyan = Color(0xFF38BDF8); // Crisp Sky Cyan
  static const Color brightTeal = Color(0xFF38BDF8); // Crisp Sky Cyan
  static const Color marineEmerald = Color(0xFF34D399); // Crisp Emerald
  static const Color warningAmber = Color(0xFFFBBF24); // Warm Amber
  static const Color coralAlert = Color(0xFFFB7185); // Rose Alert
  static const Color deepPurple = Color(0xFFA78BFA); // Soft Violet

  static const Color textPrimary = Color(0xFFF8FAFC); // Clean slate-50
  static const Color textSecondary = Color(0xFF94A3B8); // Clean slate-400
  static const Color textMuted = Color(0xFF64748B); // Clean slate-500

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: abyssNavy,
      primaryColor: bioluminescentCyan,
      canvasColor: deepSeaCard,
      colorScheme: const ColorScheme.dark(
        primary: bioluminescentCyan,
        secondary: marineEmerald,
        surface: deepSeaCard,
        error: coralAlert,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      cardTheme: CardThemeData(
        color: deepSeaCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: subseaBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepSeaCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bioluminescentCyan,
          foregroundColor: const Color(0xFF0B0F19),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: bioluminescentCyan,
        inactiveTrackColor: Color(0xFF1E293B),
        thumbColor: bioluminescentCyan,
        overlayColor: Color(0x2238BDF8),
        trackHeight: 4,
      ),
    );
  }
}

