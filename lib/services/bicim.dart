import 'package:intl/intl.dart';

/// Tarih ve para biçimlendirme yardımcıları (Türkçe).
class Bicim {
  Bicim._();

  static final _anahtar = DateFormat('yyyy-MM-dd');
  static final _kisa = DateFormat('dd.MM.yyyy', 'tr_TR');
  static final _uzun = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
  static final _gunAy = DateFormat('d MMMM EEEE', 'tr_TR');
  static final _ay = DateFormat('MMMM yyyy', 'tr_TR');
  static final _gunAdi = DateFormat('EEE', 'tr_TR');
  static final _para = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  static final _sayi = NumberFormat('#,##0.##', 'tr_TR');

  /// Kayıt anahtarı: 2026-09-25
  static String anahtar(DateTime d) => _anahtar.format(d);
  static DateTime anahtarOku(String s) => _anahtar.parse(s);

  /// 25.09.2026
  static String kisaTarih(DateTime d) => _kisa.format(d);

  /// 25 Eylül 2026, Cuma
  static String uzunTarih(DateTime d) => _uzun.format(d);

  /// 25 Eylül Cuma
  static String gunAy(DateTime d) => _gunAy.format(d);

  /// Eylül 2026
  static String ay(DateTime d) => _ay.format(d);

  /// Cum
  static String gunAdi(DateTime d) => _gunAdi.format(d);

  /// ₺1.234,50
  static String para(double v) => _para.format(v);

  /// 12,5
  static String sayi(double v) => _sayi.format(v);

  /// "1.250,50" / "1250.50" / "1250" girişlerini sayıya çevirir
  static double? sayiOku(String s) {
    var t = s.trim().replaceAll(' ', '').replaceAll('₺', '');
    if (t.isEmpty) return null;
    if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t);
  }

  /// Dosya adı için Türkçe karakter ve boşluk temizliği
  static String dosyaAdi(String s) {
    const tr = {
      'ç': 'c', 'Ç': 'C', 'ğ': 'g', 'Ğ': 'G', 'ı': 'i', 'İ': 'I',
      'ö': 'o', 'Ö': 'O', 'ş': 's', 'Ş': 'S', 'ü': 'u', 'Ü': 'U',
    };
    final b = StringBuffer();
    for (final c in s.trim().split('')) {
      b.write(tr[c] ?? c);
    }
    return b
        .toString()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static DateTime sadeceGun(DateTime d) => DateTime(d.year, d.month, d.day);
}
