import 'package:flutter/material.dart';

/// Bir günün durumu.
enum GunDurumu {
  geldi,
  yarimGun,
  gelmedi,
  ucretliIzin,
  ucretsizIzin,
  haftaTatili,
  resmiTatil,
  raporlu,
}

extension GunDurumuX on GunDurumu {
  String get etiket => const {
        GunDurumu.geldi: 'Geldim',
        GunDurumu.yarimGun: 'Yarım Gün',
        GunDurumu.gelmedi: 'Gelmedim',
        GunDurumu.ucretliIzin: 'Ücretli İzin',
        GunDurumu.ucretsizIzin: 'Ücretsiz İzin',
        GunDurumu.haftaTatili: 'Hafta Tatili',
        GunDurumu.resmiTatil: 'Resmi Tatil',
        GunDurumu.raporlu: 'Raporlu',
      }[this]!;

  /// Rapordaki durum yazısı (3. şahıs)
  String get raporEtiketi => const {
        GunDurumu.geldi: 'Geldi',
        GunDurumu.yarimGun: 'Yarım Gün',
        GunDurumu.gelmedi: 'Gelmedi',
        GunDurumu.ucretliIzin: 'Ücretli İzin',
        GunDurumu.ucretsizIzin: 'Ücretsiz İzin',
        GunDurumu.haftaTatili: 'Hafta Tatili',
        GunDurumu.resmiTatil: 'Resmi Tatil',
        GunDurumu.raporlu: 'Raporlu',
      }[this]!;

  /// Takvim hücresindeki kısa kod
  String get kisa => const {
        GunDurumu.geldi: 'G',
        GunDurumu.yarimGun: 'Y',
        GunDurumu.gelmedi: 'X',
        GunDurumu.ucretliIzin: 'Üİ',
        GunDurumu.ucretsizIzin: 'Sİ',
        GunDurumu.haftaTatili: 'HT',
        GunDurumu.resmiTatil: 'RT',
        GunDurumu.raporlu: 'R',
      }[this]!;

  Color get renk => const {
        GunDurumu.geldi: Color(0xFF2E7D32),
        GunDurumu.yarimGun: Color(0xFFEF6C00),
        GunDurumu.gelmedi: Color(0xFFC62828),
        GunDurumu.ucretliIzin: Color(0xFF1565C0),
        GunDurumu.ucretsizIzin: Color(0xFF6D4C41),
        GunDurumu.haftaTatili: Color(0xFF607D8B),
        GunDurumu.resmiTatil: Color(0xFF00897B),
        GunDurumu.raporlu: Color(0xFFAD1457),
      }[this]!;

  IconData get ikon => const {
        GunDurumu.geldi: Icons.check_circle,
        GunDurumu.yarimGun: Icons.timelapse,
        GunDurumu.gelmedi: Icons.cancel,
        GunDurumu.ucretliIzin: Icons.beach_access,
        GunDurumu.ucretsizIzin: Icons.event_busy,
        GunDurumu.haftaTatili: Icons.weekend,
        GunDurumu.resmiTatil: Icons.flag,
        GunDurumu.raporlu: Icons.medical_services,
      }[this]!;

  /// AYLIKÇI için maaştan düşülecek gün (gelmedi, ücretsiz izin, raporlu: 1; yarım: 0,5).
  /// (Raporlu günler, profilde "rapor tam ödenir" açıksa hesaplamada düşülmez.)
  /// Hafta tatili, resmi tatil ve ücretli izin maaştan düşülmez.
  double get aylikKesintiGunu {
    switch (this) {
      case GunDurumu.gelmedi:
      case GunDurumu.ucretsizIzin:
      case GunDurumu.raporlu:
        return 1;
      case GunDurumu.yarimGun:
        return 0.5;
      default:
        return 0;
    }
  }

  /// YEVMİYECİ için ücret ödenecek gün (geldi ve ücretli izin: 1; yarım: 0,5).
  double get gunlukOdenenGun {
    switch (this) {
      case GunDurumu.geldi:
      case GunDurumu.ucretliIzin:
        return 1;
      case GunDurumu.yarimGun:
        return 0.5;
      default:
        return 0;
    }
  }

  /// Bu durumda fazla mesai girilebilir mi? (tatilde çalışma dahil)
  bool get mesaiGirilebilir =>
      this == GunDurumu.geldi ||
      this == GunDurumu.yarimGun ||
      this == GunDurumu.haftaTatili ||
      this == GunDurumu.resmiTatil;

  /// Giriş-çıkış saati girilebilir mi?
  bool get saatGirilebilir => mesaiGirilebilir;

  static GunDurumu adindan(String? ad) => GunDurumu.values
      .firstWhere((d) => d.name == ad, orElse: () => GunDurumu.geldi);
}

/// Rapor türü (SGK rapor parası hesabı için)
enum RaporTuru {
  /// Hastalık - ayakta tedavi: 3. günden itibaren günlük kazancın 2/3'ü
  ayakta,

  /// Hastalık - yatarak tedavi: 3. günden itibaren günlük kazancın 1/2'si
  yatarak,

  /// İş kazası / meslek hastalığı: 1. günden itibaren günlük kazancın 2/3'ü
  isKazasi,
}

extension RaporTuruX on RaporTuru {
  String get etiket => const {
        RaporTuru.ayakta: 'Ayakta tedavi',
        RaporTuru.yatarak: 'Yatarak (hastane)',
        RaporTuru.isKazasi: 'İş kazası',
      }[this]!;

  /// SGK'nın ödediği oran (günlük kazancın)
  double get oran => this == RaporTuru.yatarak ? 0.5 : 2 / 3;

  /// SGK kaçıncı günden itibaren öder? (hastalıkta ilk 2 gün ödenmez)
  int get odemeBaslangicGunu => this == RaporTuru.isKazasi ? 1 : 3;

  static RaporTuru adindan(String? ad) => RaporTuru.values
      .firstWhere((t) => t.name == ad, orElse: () => RaporTuru.ayakta);
}

/// Bir günün puantaj kaydı. Tarih (yyyy-MM-dd) benzersiz anahtardır.
class GunKaydi {
  final String tarih;
  final GunDurumu durum;
  final String? giris; // "08:00"
  final String? cikis; // "18:30"
  final double mesaiSaat;
  final String? not;

  /// Sadece durum "Raporlu" ise anlamlı
  final RaporTuru raporTuru;

  const GunKaydi({
    required this.tarih,
    required this.durum,
    this.giris,
    this.cikis,
    this.mesaiSaat = 0,
    this.not,
    this.raporTuru = RaporTuru.ayakta,
  });

  Map<String, dynamic> toJson() => {
        'tarih': tarih,
        'durum': durum.name,
        if (giris != null) 'giris': giris,
        if (cikis != null) 'cikis': cikis,
        if (mesaiSaat > 0) 'mesai': mesaiSaat,
        if (not != null && not!.isNotEmpty) 'not': not,
        if (durum == GunDurumu.raporlu) 'rapor': raporTuru.name,
      };

  factory GunKaydi.fromJson(Map<String, dynamic> j) => GunKaydi(
        tarih: j['tarih'] as String,
        durum: GunDurumuX.adindan(j['durum'] as String?),
        giris: j['giris'] as String?,
        cikis: j['cikis'] as String?,
        mesaiSaat: (j['mesai'] as num?)?.toDouble() ?? 0,
        not: j['not'] as String?,
        raporTuru: RaporTuruX.adindan(j['rapor'] as String?),
      );

  GunKaydi copyWith({
    GunDurumu? durum,
    double? mesaiSaat,
  }) =>
      GunKaydi(
        tarih: tarih,
        durum: durum ?? this.durum,
        giris: giris,
        cikis: cikis,
        mesaiSaat: mesaiSaat ?? this.mesaiSaat,
        not: not,
        raporTuru: raporTuru,
      );

  /// Giriş-çıkış arası toplam süre (saat). Gece yarısını geçen vardiya desteklenir.
  static double? sureHesapla(String? giris, String? cikis) {
    final g = _dakika(giris), c = _dakika(cikis);
    if (g == null || c == null) return null;
    var fark = c - g;
    if (fark <= 0) fark += 24 * 60;
    return fark / 60;
  }

  /// Giriş-çıkış saatinden önerilen mesai (mola ve normal süre düşülür, 0,5'e yuvarlanır)
  static double mesaiOner(
      String? giris, String? cikis, double gunlukSaat, double mola) {
    final sure = sureHesapla(giris, cikis);
    if (sure == null) return 0;
    final fazla = sure - mola - gunlukSaat;
    if (fazla <= 0) return 0;
    return (fazla * 2).round() / 2;
  }

  static int? _dakika(String? s) {
    if (s == null || !s.contains(':')) return null;
    final p = s.split(':');
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
