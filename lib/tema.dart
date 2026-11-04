import 'package:flutter/material.dart';

/// Uygulamanın renkleri (krem zemin, koyu lacivert, yeşil vurgu).
class Renkler {
  Renkler._();

  static const lacivert = Color(0xFF1B2B45);
  static const lacivertAcik = Color(0xFF2A3D5C);
  static const yesil = Color(0xFF1FA37A);
  static const yesilAcik = Color(0xFFCDEFE2);
  static const turuncu = Color(0xFFF0A023);
  static const kirmizi = Color(0xFFD9534F);
  static const gri = Color(0xFF9AA3AF);
  static const krem = Color(0xFFF7F5F0);
  static const kart = Color(0xFFFFFFFF);
  static const cizgi = Color(0xFFE7E4DD);
  static const metin = Color(0xFF1B2B45);
  static const ikinciMetin = Color(0xFF5F6B7A);

  // Koyu tema karşılıkları
  static const koyuZemin = Color(0xFF0F1724);
  static const koyuKart = Color(0xFF182335);
  static const koyuCizgi = Color(0xFF26344A);
}

/// Material 3 açık / koyu tema.
class UygulamaTemasi {
  UygulamaTemasi._();

  static const tohumRenk = Renkler.lacivert;

  static ThemeData get acik => _olustur(Brightness.light);
  static ThemeData get koyu => _olustur(Brightness.dark);

  static ThemeData _olustur(Brightness parlaklik) {
    final koyu = parlaklik == Brightness.dark;
    final zemin = koyu ? Renkler.koyuZemin : Renkler.krem;
    final kart = koyu ? Renkler.koyuKart : Renkler.kart;
    final cizgi = koyu ? Renkler.koyuCizgi : Renkler.cizgi;
    final metin = koyu ? const Color(0xFFE8ECF2) : Renkler.metin;

    final r = ColorScheme.fromSeed(seedColor: tohumRenk, brightness: parlaklik).copyWith(
      primary: koyu ? const Color(0xFF8FB4E8) : Renkler.lacivert,
      onPrimary: koyu ? Renkler.koyuZemin : Colors.white,
      primaryContainer: koyu ? Renkler.lacivertAcik : Renkler.lacivert,
      onPrimaryContainer: Colors.white,
      secondary: Renkler.yesil,
      onSecondary: Colors.white,
      secondaryContainer: koyu ? const Color(0xFF1D4A3C) : Renkler.yesilAcik,
      onSecondaryContainer: koyu ? Renkler.yesilAcik : const Color(0xFF0E4A37),
      tertiary: Renkler.turuncu,
      surface: zemin,
      onSurface: metin,
      onSurfaceVariant: koyu ? const Color(0xFFA9B4C4) : Renkler.ikinciMetin,
      surfaceContainerLowest: kart,
      surfaceContainerLow: kart,
      surfaceContainer: kart,
      surfaceContainerHigh: koyu ? const Color(0xFF1F2B40) : const Color(0xFFF1EFEA),
      surfaceContainerHighest: koyu ? const Color(0xFF243249) : const Color(0xFFECE9E2),
      outline: koyu ? const Color(0xFF5C6B82) : Renkler.gri,
      outlineVariant: cizgi,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: r,
      scaffoldBackgroundColor: zemin,
      // Gömülü yazı tipi: web sürümü internetsizken de düzgün görünsün
      fontFamily: 'DejaVu',
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: zemin,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: metin,
        titleTextStyle: TextStyle(
          fontFamily: 'DejaVu',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: metin,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: kart,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cizgi),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: cizgi, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cizgi),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cizgi),
        ),
        filled: true,
        fillColor: kart,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'DejaVu', fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: cizgi),
          foregroundColor: metin,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Renkler.yesil,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kart,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 66,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? Renkler.yesil : metin,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: 'DejaVu',
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? Renkler.yesil : metin,
            )),
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: kart,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(backgroundColor: kart, surfaceTintColor: Colors.transparent),
    );
  }
}
