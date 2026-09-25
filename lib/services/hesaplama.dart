import '../models/gun_kaydi.dart';
import '../models/para_hareketi.dart';
import '../models/profil.dart';

/// Bir ayın puantaj ve hakediş özeti.
class AylikOzet {
  final DateTime ay; // Ayın 1'i
  final int gunSayisi; // Ayın gün sayısı (28-31)
  final Map<GunDurumu, int> sayac; // Durum -> gün adedi
  final int isaretsizGun; // Bugüne kadar hiç girilmemiş gün
  final double mesaiSaat;

  final UcretTipi ucretTipi;
  final double ucret; // Aylık maaş veya yevmiye
  final double gunlukUcret;
  final double saatlikUcret;
  final double mesaiKatsayisi;

  /// Aylıkçı: maaştan düşülecek gün. Yevmiyeci: 0
  final double kesintiGunu;

  /// Yevmiyeci: ücret ödenecek gün. Aylıkçı: 30 - kesinti gün
  final double odenenGun;

  final double temelUcret; // Maaş - devamsızlık (aylık) veya gün × yevmiye
  final double mesaiUcreti;
  final double ekOdeme;
  final double avans;
  final double kesinti;

  const AylikOzet({
    required this.ay,
    required this.gunSayisi,
    required this.sayac,
    required this.isaretsizGun,
    required this.mesaiSaat,
    required this.ucretTipi,
    required this.ucret,
    required this.gunlukUcret,
    required this.saatlikUcret,
    required this.mesaiKatsayisi,
    required this.kesintiGunu,
    required this.odenenGun,
    required this.temelUcret,
    required this.mesaiUcreti,
    required this.ekOdeme,
    required this.avans,
    required this.kesinti,
  });

  int adet(GunDurumu d) => sayac[d] ?? 0;

  /// Çalışılan gün (geldi + yarım × 0,5)
  double get calisilanGun => adet(GunDurumu.geldi) + adet(GunDurumu.yarimGun) * 0.5;

  /// Devamsızlık kesintisi tutarı (aylıkçı için)
  double get devamsizlikTutari => kesintiGunu * gunlukUcret;

  /// Brüt hakediş: temel ücret + mesai + ek ödemeler
  double get brut => temelUcret + mesaiUcreti + ekOdeme;

  /// Elime geçecek: brüt - avans - kesinti
  double get net => brut - avans - kesinti;
}

/// Hesap kuralları:
///
/// AYLIK MAAŞ:
///   Günlük = maaş ÷ 30
///   Temel  = maaş − (Gelmedi + Ücretsiz İzin + Raporlu + Yarım×0,5) × günlük
///   (Hafta tatili, resmi tatil, ücretli izin ve işaretlenmemiş günler düşülmez)
///
/// GÜNLÜK YEVMİYE:
///   Temel  = (Geldi + Ücretli İzin + Yarım×0,5) × yevmiye
///
/// HER İKİSİ:
///   Saatlik = günlük ÷ günlük çalışma saati (7,5)
///   Mesai   = mesai saati × saatlik × katsayı (1,5)
///   Net     = Temel + Mesai + Ek ödeme − Avans − Kesinti
class Hesaplama {
  Hesaplama._();

  static AylikOzet hesapla({
    required Profil profil,
    required DateTime ay,
    required Iterable<GunKaydi> kayitlar,
    required Iterable<ParaHareketi> hareketler,
    DateTime? bugun,
  }) {
    final ayBasi = DateTime(ay.year, ay.month, 1);
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    final simdi = bugun ?? DateTime.now();
    final bugunGun = DateTime(simdi.year, simdi.month, simdi.day);

    final sayac = <GunDurumu, int>{};
    double mesai = 0, kesintiGun = 0, odenenGunlukte = 0;
    final girilenTarihler = <String>{};

    for (final k in kayitlar) {
      sayac[k.durum] = (sayac[k.durum] ?? 0) + 1;
      mesai += k.mesaiSaat;
      kesintiGun += k.durum.aylikKesintiGunu;
      odenenGunlukte += k.durum.gunlukOdenenGun;
      girilenTarihler.add(k.tarih);
    }

    // Bugüne kadar (bugün dahil) hiç girilmemiş gün sayısı
    var isaretsiz = 0;
    for (var g = 1; g <= gunSayisi; g++) {
      final t = DateTime(ay.year, ay.month, g);
      if (t.isAfter(bugunGun)) break;
      final anahtar =
          '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      if (!girilenTarihler.contains(anahtar)) isaretsiz++;
    }

    double ekOdeme = 0, avans = 0, kesinti = 0;
    for (final h in hareketler) {
      switch (h.tur) {
        case HareketTuru.ekOdeme:
          ekOdeme += h.tutar;
          break;
        case HareketTuru.avans:
          avans += h.tutar;
          break;
        case HareketTuru.kesinti:
          kesinti += h.tutar;
          break;
      }
    }

    final gunluk = profil.gunlukUcret;
    final saatlik = profil.saatlikUcret;
    final aylik = profil.ucretTipi == UcretTipi.aylik;

    final double temel;
    final double odenenGun;
    final double kesintiGunu;
    if (aylik) {
      kesintiGunu = kesintiGun > 30 ? 30 : kesintiGun;
      odenenGun = 30 - kesintiGunu;
      temel = profil.ucret - kesintiGunu * gunluk;
    } else {
      kesintiGunu = 0;
      odenenGun = odenenGunlukte;
      temel = odenenGunlukte * gunluk;
    }

    return AylikOzet(
      ay: ayBasi,
      gunSayisi: gunSayisi,
      sayac: sayac,
      isaretsizGun: isaretsiz,
      mesaiSaat: mesai,
      ucretTipi: profil.ucretTipi,
      ucret: profil.ucret,
      gunlukUcret: gunluk,
      saatlikUcret: saatlik,
      mesaiKatsayisi: profil.mesaiKatsayisi,
      kesintiGunu: kesintiGunu,
      odenenGun: odenenGun,
      temelUcret: temel,
      mesaiUcreti: mesai * saatlik * profil.mesaiKatsayisi,
      ekOdeme: ekOdeme,
      avans: avans,
      kesinti: kesinti,
    );
  }
}
