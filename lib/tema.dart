import 'package:flutter/material.dart';

/// Material Design 3 açık / koyu tema.
class UygulamaTemasi {
  UygulamaTemasi._();

  static const tohumRenk = Color(0xFF1E6FA8);

  static ThemeData get acik => _olustur(Brightness.light);
  static ThemeData get koyu => _olustur(Brightness.dark);

  static ThemeData _olustur(Brightness parlaklik) {
    final r = ColorScheme.fromSeed(seedColor: tohumRenk, brightness: parlaklik);
    return ThemeData(
      useMaterial3: true,
      colorScheme: r,
      // Gömülü yazı tipi: web sürümü internetsizken de düzgün görünsün
      fontFamily: 'DejaVu',
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: r.surface,
        surfaceTintColor: r.surfaceTint,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: r.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: r.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: r.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
    );
  }
}
