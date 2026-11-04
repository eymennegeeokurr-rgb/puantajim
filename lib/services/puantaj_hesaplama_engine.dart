import '../models/gun_kaydi.dart';

/// Bir haftanın (Pazartesi–Cumartesi) çalışma süresi ve o haftanın Pazar kararı.
class HaftaSonucu {
  /// Haftanın Pazar günü
  final DateTime pazar;

  /// Girilen günlerdeki toplam saat (çalışılan + mazeretli + fazla mesai)
  final double calisilanSaat;

  /// Girilen gün sayısı × günlük saat. Hafta tam girilmişse 6 × 7,5 = 45.
  final double gerekenSaat;

  /// Pzt–Cmt arasında kaydı olan gün sayısı
  final int girilenGun;

  /// Pazar kaydında "Patron İnisiyatifi: Pazar Ücretini Ver" işaretli mi?
  final bool inisiyatif;

  const HaftaSonucu({
    required this.pazar,
    required this.calisilanSaat,
    required this.gerekenSaat,
    required this.girilenGun,
    required this.inisiyatif,
  });

  /// Haftada en az bir gün girilmiş mi?
  bool get kayitVar => girilenGun > 0;

  /// 45 saat (girilen günlerin gerektirdiği saat) tamamlandı mı?
  bool get tamamlandi => calisilanSaat + 0.001 >= gerekenSaat;

  /// Kayıt var ve saat eksik
  bool get eksik => kayitVar && !tamamlandi;

  double get eksikSaat => eksik ? gerekenSaat - calisilanSaat : 0;
}

/// Uyuşmazlık türü (patron kaydı ile işçinin kendi kaydı)
enum Uyusmazlik {
  /// İki taraf da girmiş ama durum veya mesai farklı
  farkli,

  /// İşçi girmiş, patron henüz girmemiş
  patronGirmedi,

  /// Patron girmiş, işçi girmemiş
  isciGirmedi,
}

/// Puantaj hesap kuralları (İş Kanunu):
///
///   SAATLİK ÜCRET = günlük ücret ÷ 7,5 saat (haftalık 45 saat ÷ 6 gün)
///   FAZLA MESAİ   = bu saatlik ücret × mesai katsayısı (%50 zamlı = 1,5)
///
///   HAFTA TATİLİ (Pazar): Pzt–Cmt arası girilen günlerin toplam saati,
///   o günlerin gerektirdiği saati (tam haftada 45) tamamlamıyorsa Pazar
///   ücreti kesilir. Saat sayımı:
///     Geldi           = 7,5 + fazla mesai
///     Yarım gün       = 3,75 + fazla mesai
///     Ücretli izin, ücretsiz izin, raporlu, resmi tatil, hafta tatili
///                     = 7,5 (mazeretli gün, + varsa mesai)
///     Gelmedi         = 0
///     Girilmemiş gün  = hesaba katılmaz (uyarı olarak ayrıca gösterilir)
///   Patron inisiyatifi işaretliyse saat eksik olsa da Pazar ücreti verilir.
class PuantajHesaplamaEngine {
  PuantajHesaplamaEngine._();

  /// İş Kanunu: haftalık 45 saat ÷ 6 gün
  static const double varsayilanGunlukSaat = 7.5;

  /// Haftada çalışılan gün (Pzt–Cmt)
  static const int haftalikIsGunu = 6;

  /// Haftalık yasal çalışma süresi (gunlukSaat × 6)
  static double haftalikSaat({double gunlukSaat = varsayilanGunlukSaat}) =>
      gunlukSaat * haftalikIsGunu;

  /// Saatlik ücret = günlük ücret ÷ günlük saat (7,5)
  static double saatlikUcret(double gunlukUcret,
          {double gunlukSaat = varsayilanGunlukSaat}) =>
      gunlukSaat > 0 ? gunlukUcret / gunlukSaat : 0;

  /// Fazla mesai ücreti
  static double mesaiUcreti(double mesaiSaat, double gunlukUcret,
          {double gunlukSaat = varsayilanGunlukSaat, double katsayi = 1.5}) =>
      mesaiSaat * saatlikUcret(gunlukUcret, gunlukSaat: gunlukSaat) * katsayi;

  /// Bir günün 45 saat hesabına giren süresi
  static double gunSaati(GunKaydi k, {double gunlukSaat = varsayilanGunlukSaat}) {
    final double temel;
    switch (k.durum) {
      case GunDurumu.geldi:
        temel = gunlukSaat;
        break;
      case GunDurumu.yarimGun:
        temel = gunlukSaat / 2;
        break;
      case GunDurumu.gelmedi:
        temel = 0;
        break;
      case GunDurumu.ucretliIzin:
      case GunDurumu.ucretsizIzin:
      case GunDurumu.raporlu:
      case GunDurumu.resmiTatil:
      case GunDurumu.haftaTatili:
        temel = gunlukSaat; // mazeretli gün
        break;
    }
    return temel + (k.durum == GunDurumu.gelmedi ? 0 : k.mesaiSaat);
  }

  /// [pazar] gününün haftasını (önceki Pzt–Cmt) değerlendirir.
  /// [kayitBul] tarihe göre kaydı verir (önceki aydan da bakabilir).
  static HaftaSonucu hafta(
    DateTime pazar,
    GunKaydi? Function(DateTime) kayitBul, {
    double gunlukSaat = varsayilanGunlukSaat,
  }) {
    double saat = 0;
    var girilen = 0;
    for (var i = 1; i <= haftalikIsGunu; i++) {
      final k = kayitBul(DateTime(pazar.year, pazar.month, pazar.day - i));
      if (k == null) continue;
      girilen++;
      saat += gunSaati(k, gunlukSaat: gunlukSaat);
    }
    final pazarKaydi = kayitBul(pazar);
    return HaftaSonucu(
      pazar: pazar,
      calisilanSaat: saat,
      gerekenSaat: girilen * gunlukSaat,
      girilenGun: girilen,
      inisiyatif: pazarKaydi?.pazarUcretiVer ?? false,
    );
  }

  /// Pazar ücreti kesilir mi? (kesinti ayarı açık, saat eksik, inisiyatif yok)
  static bool pazarKesilir(HaftaSonucu h, {required bool kesintiAcik}) =>
      kesintiAcik && h.eksik && !h.inisiyatif;

  /// Saat eksik ama patron inisiyatifiyle Pazar ücreti verildi mi?
  static bool inisiyatifleVerildi(HaftaSonucu h, {required bool kesintiAcik}) =>
      kesintiAcik && h.eksik && h.inisiyatif;

  /// Patron ve işçi kaydını karşılaştırır. Uyuşuyorsa (veya ikisi de boşsa) null.
  static Uyusmazlik? karsilastir(GunKaydi? patron, GunKaydi? isci) {
    if (patron == null && isci == null) return null;
    if (patron == null) return Uyusmazlik.patronGirmedi;
    if (isci == null) return Uyusmazlik.isciGirmedi;
    return patron.ayniMi(isci) ? null : Uyusmazlik.farkli;
  }
}
