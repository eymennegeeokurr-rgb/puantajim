import 'dart:convert';

import 'gun_kaydi.dart';
import 'not_kaydi.dart';
import 'para_hareketi.dart';
import 'profil.dart';

/// Bir kişinin tüm verisi (profil + günler + avanslar + notlar).
///
/// Aynı JSON biçimi hem yedek dosyasında hem de bulutta (Firebase) kullanılır.
/// Yönetici paneli de elemanın verisini bu sınıfla okur.
class VeriPaketi {
  static const uygulamaAdi = 'puantajim';
  static const surum = 1;

  final Profil? profil;
  final List<GunKaydi> gunler;
  final List<ParaHareketi> hareketler;
  final List<NotKaydi> notlar;

  const VeriPaketi({
    required this.profil,
    required this.gunler,
    required this.hareketler,
    required this.notlar,
  });

  bool get bos =>
      profil == null && gunler.isEmpty && hareketler.isEmpty && notlar.isEmpty;

  Map<String, dynamic> toJson() => {
        'uygulama': uygulamaAdi,
        'surum': surum,
        'tarih': DateTime.now().toIso8601String(),
        'profil': profil?.toJson(),
        'gunler': gunler.map((g) => g.toJson()).toList(),
        'hareketler': hareketler.map((h) => h.toJson()).toList(),
        'notlar': notlar.map((n) => n.toJson()).toList(),
      };

  String metin({bool girintili = false}) => girintili
      ? const JsonEncoder.withIndent(' ').convert(toJson())
      : jsonEncode(toJson());

  /// JSON metninden okur. Puantajım verisi değilse FormatException fırlatır.
  static VeriPaketi ayristir(String metin) {
    final j = jsonDecode(metin);
    if (j is! Map<String, dynamic> || j['uygulama'] != uygulamaAdi) {
      throw const FormatException('Bu dosya bir Puantajım yedeği değil');
    }
    return VeriPaketi(
      profil: j['profil'] == null
          ? null
          : Profil.fromJson(j['profil'] as Map<String, dynamic>),
      gunler: (j['gunler'] as List<dynamic>? ?? [])
          .map((e) => GunKaydi.fromJson(e as Map<String, dynamic>))
          .toList(),
      hareketler: (j['hareketler'] as List<dynamic>? ?? [])
          .map((e) => ParaHareketi.fromJson(e as Map<String, dynamic>))
          .toList(),
      notlar: (j['notlar'] as List<dynamic>? ?? [])
          .map((e) => NotKaydi.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ---- Ay filtreleri (yönetici panelinde kullanılır)

  static String _onEk(DateTime ay) =>
      '${ay.year.toString().padLeft(4, '0')}-${ay.month.toString().padLeft(2, '0')}-';

  List<GunKaydi> ayKayitlari(DateTime ay) {
    final o = _onEk(ay);
    return gunler.where((k) => k.tarih.startsWith(o)).toList()
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
  }

  List<ParaHareketi> ayHareketleri(DateTime ay) {
    final o = _onEk(ay);
    return hareketler.where((h) => h.tarih.startsWith(o)).toList()
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
  }

  List<NotKaydi> ayNotlari(DateTime ay) {
    final o = _onEk(ay);
    return notlar.where((n) => n.tarih.startsWith(o)).toList()
      ..sort((a, b) {
        final t = a.tarih.compareTo(b.tarih);
        return t != 0 ? t : a.saat.compareTo(b.saat);
      });
  }
}
