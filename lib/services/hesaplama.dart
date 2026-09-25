import '../models/gun_kaydi.dart';
import '../models/para_hareketi.dart';
import '../models/profil.dart';

/// Yıllara göre asgari ücret (aylık, 30 gün).
/// Yeni yılın asgari ücreti açıklanınca buraya bir satır eklenir.
class AsgariUcret {
  AsgariUcret._();

  static const Map<int, ({double net, double brut})> tablo = {
    2025: (net: 22104.67, brut: 26005.50),
    2026: (net: 28075.50, brut: 33030.00),
  };

  /// O yılın asgari ücreti (tabloda yoksa en yakın önceki yıl)
  static ({double net, double brut, int yil}) yil(int y) {
    final yillar = tablo.keys.toList()..sort();
    var secilen = yillar.first;
    for (final k in yillar) {
      if (k <= y) secilen = k;
    }
    final d = tablo[secilen]!;
    return (net: d.net, brut: d.brut, yil: secilen);
  }
}

/// Bir ayın puantaj ve hakediş özeti.
class AylikOzet {
  final DateTime ay; // Ayın 1'i
  final int gunSayisi; // Ayın gün sayısı (28-31)
  final Map<GunDurumu, int> sayac; // Durum -> gün adedi
  final int isaretsizGun; // Bugüne kadar hiç girilmemiş gün
  final double mesaiSaat;

  final UcretTipi ucretTipi;
  final double ucret; // Aylık toplam maaş
  final double gunlukUcret;
  final double saatlikUcret;
  final double mesaiKatsayisi;

  /// Maaştan düşülen gün (31 çeken ay telafisi sonrası)
  final double kesintiGunu;

  /// Ücret ödenen gün (en fazla 30)
  final double odenenGun;

  final double temelUcret; // Ödenen gün × günlük ücret
  final double mesaiUcreti;
  final double ekOdeme;
  final double avans;
  final double kesinti;

  // ---- Rapor ----
  final int raporGunu; // Bu aydaki raporlu gün
  final double sgkOdenekGunu; // SGK'nın ödeme yaptığı gün (oran farkı dahil değil)
  final double sgkGunlukKazanc; // SGK'nın esas aldığı günlük brüt kazanç
  final double sgkOdenegi; // Tahmini SGK rapor parası (SGK doğrudan öder)
  final bool raporTamOdenir;

  // ---- Banka / elden ----
  final BankaTipi bankaTipi;
  final double bankaAylik; // 30 günlük bankaya yatan tutar
  final int asgariYili; // Asgari ücret seçiliyse hangi yılın rakamı
  final double primGunu; // Bankaya yatan / SGK'ya bildirilen gün
  final double hacizOrani;
  final String hacizEtiketi;

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
    required this.raporGunu,
    required this.sgkOdenekGunu,
    required this.sgkGunlukKazanc,
    required this.sgkOdenegi,
    required this.raporTamOdenir,
    required this.bankaTipi,
    required this.bankaAylik,
    required this.asgariYili,
    required this.primGunu,
    required this.hacizOrani,
    required this.hacizEtiketi,
  });

  int adet(GunDurumu d) => sayac[d] ?? 0;

  /// Çalışılan gün (geldi + yarım × 0,5)
  double get calisilanGun =>
      adet(GunDurumu.geldi) + adet(GunDurumu.yarimGun) * 0.5;

  /// Eksik gün kesintisi tutarı
  double get devamsizlikTutari => kesintiGunu * gunlukUcret;

  /// Toplam hak: temel ücret + mesai + ek ödemeler
  double get brut => temelUcret + mesaiUcreti + ekOdeme;

  /// SGK'nın ödediği ve işverenin ödeyeceğinden düşülen tutar
  /// (sadece "rapor tam ödenir" açıkken düşülür)
  double get sgkDusulen => raporTamOdenir ? sgkOdenegi : 0;

  /// İşverenin bu ay ödeyeceği toplam (banka + elden)
  double get net => brut - sgkDusulen - avans - kesinti;

  /// Bankaya yatacak brüt tutar (haciz öncesi): banka günlüğü × prim günü
  double get bankaHakedis => bankaAylik / 30 * primGunu;

  /// Haciz kesintisi (bankaya yatandan, icraya gider)
  double get haciz => bankaHakedis * hacizOrani;

  /// Bankaya net yatacak (haciz düşülmüş)
  double get bankayaYatan => bankaHakedis - haciz;

  /// Elden ödenecek: işverenin toplam ödemesi − bankaya giden (haciz dahil)
  double get elden => net - bankaHakedis;

  bool get bankaVar => bankaTipi != BankaTipi.yok && bankaAylik > 0;
}

/// Hesap kuralları (aylıkçı, her ay 30 gün):
///
///   Günlük       = maaş ÷ 30
///   Eksik gün    = Gelmedi + Ücretsiz İzin + Yarım×0,5 (+ Raporlu, "rapor tam
///                  ödenir" kapalıysa)
///   Ödenen gün   = 31 çeken ayda 31 − eksik (en fazla 30), diğerlerinde 30 − eksik
///   Temel        = ödenen gün × günlük
///   Mesai        = mesai saati × (günlük ÷ 7,5) × 1,5
///   Toplam hak   = temel + mesai + ek ödeme
///
/// RAPOR (SGK geçici iş göremezlik ödeneği, tahmini):
///   Günlük kazanç = SGK brüt ÷ 30 (en az brüt asgari/30, en fazla 9 katı)
///   Hastalık: 3. günden itibaren; ayakta 2/3, yatarak 1/2
///   İş kazası: 1. günden itibaren 2/3
///   "Rapor tam ödenir" açıkken: raporlu günler maaştan düşülmez; SGK'nın
///   ödediği tutar işverenin ödeyeceğinden düşülür (farkı işveren öder).
///
/// BANKA / ELDEN:
///   Prim günü    = 31 çeken ayda 31 − (eksik + raporlu) (en fazla 30), diğer 30 − ...
///   Banka        = (bankaya yatan 30 günlük tutar ÷ 30) × prim günü
///   Haciz        = banka × oran (1/4 veya 1/10) → icraya
///   Bankaya net  = banka − haciz
///   Elden        = (toplam hak − SGK payı − avans − kesinti) − banka
class Hesaplama {
  Hesaplama._();

  static String _anahtar(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  static AylikOzet hesapla({
    required Profil profil,
    required DateTime ay,
    required Iterable<GunKaydi> kayitlar,
    required Iterable<ParaHareketi> hareketler,
    Iterable<GunKaydi> oncekiAyKayitlari = const [],
    DateTime? bugun,
  }) {
    final ayBasi = DateTime(ay.year, ay.month, 1);
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    final simdi = bugun ?? DateTime.now();
    final bugunGun = DateTime(simdi.year, simdi.month, simdi.day);
    final asgari = AsgariUcret.yil(ay.year);

    final sayac = <GunDurumu, int>{};
    double mesai = 0, eksikGun = 0, odenenGunlukte = 0;
    var raporGunu = 0;
    final harita = <String, GunKaydi>{};

    for (final k in kayitlar) {
      sayac[k.durum] = (sayac[k.durum] ?? 0) + 1;
      mesai += k.mesaiSaat;
      odenenGunlukte += k.durum.gunlukOdenenGun;
      harita[k.tarih] = k;
      if (k.durum == GunDurumu.raporlu) {
        raporGunu++;
      } else {
        eksikGun += k.durum.aylikKesintiGunu;
      }
    }

    // Bugüne kadar (bugün dahil) hiç girilmemiş gün sayısı
    var isaretsiz = 0;
    for (var g = 1; g <= gunSayisi; g++) {
      final t = DateTime(ay.year, ay.month, g);
      if (t.isAfter(bugunGun)) break;
      if (!harita.containsKey(_anahtar(t))) isaretsiz++;
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
    final taban = gunSayisi >= 31 ? 31.0 : 30.0;

    double otuzaSinirla(double v) => v > 30 ? 30.0 : (v < 0 ? 0.0 : v);

    // ---- Ücret ödenen gün
    final maastanDusulen =
        eksikGun + (profil.raporTamOdenir ? 0 : raporGunu.toDouble());
    final double temel;
    final double odenenGun;
    final double kesintiGunu;
    if (aylik) {
      odenenGun = otuzaSinirla(taban - maastanDusulen);
      kesintiGunu = 30 - odenenGun;
      temel = odenenGun * gunluk;
    } else {
      kesintiGunu = 0;
      odenenGun = odenenGunlukte;
      temel = odenenGunlukte * gunluk;
    }

    // ---- SGK rapor parası (tahmini)
    // Rapor ardışık günlerden oluşur; önceki aydan devam eden rapor da sayılır
    final oncekiHarita = {for (final k in oncekiAyKayitlari) k.tarih: k};
    GunKaydi? kayitBul(DateTime t) =>
        harita[_anahtar(t)] ?? oncekiHarita[_anahtar(t)];

    final brutAylik = profil.sgkBrut > 0 ? profil.sgkBrut : asgari.brut;
    var sgkGunluk = brutAylik / 30;
    final altSinir = asgari.brut / 30;
    final ustSinir = asgari.brut * 9 / 30;
    if (sgkGunluk < altSinir) sgkGunluk = altSinir;
    if (sgkGunluk > ustSinir) sgkGunluk = ustSinir;

    double sgkOdenegi = 0, sgkGun = 0;
    for (var g = 1; g <= gunSayisi; g++) {
      final t = DateTime(ay.year, ay.month, g);
      final k = harita[_anahtar(t)];
      if (k == null || k.durum != GunDurumu.raporlu) continue;
      // Bu raporun kaçıncı günü? (geriye doğru ardışık raporlu günleri say)
      var sira = 1;
      var onceki = DateTime(t.year, t.month, t.day - 1);
      while (true) {
        final o = kayitBul(onceki);
        if (o == null || o.durum != GunDurumu.raporlu) break;
        sira++;
        onceki = DateTime(onceki.year, onceki.month, onceki.day - 1);
      }
      if (sira >= k.raporTuru.odemeBaslangicGunu) {
        sgkGun++;
        sgkOdenegi += sgkGunluk * k.raporTuru.oran;
      }
    }

    // ---- Banka
    final bankaAylik = switch (profil.bankaTipi) {
      BankaTipi.yok => 0.0,
      BankaTipi.asgari => asgari.net,
      BankaTipi.ozel => profil.bankaTutar,
    };
    // Raporlu günler SGK'ya prim günü olarak bildirilmez → bankaya yatmaz
    final primGunu = otuzaSinirla(taban - eksikGun - raporGunu);

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
      raporGunu: raporGunu,
      sgkOdenekGunu: sgkGun,
      sgkGunlukKazanc: sgkGunluk,
      sgkOdenegi: sgkOdenegi,
      raporTamOdenir: profil.raporTamOdenir,
      bankaTipi: profil.bankaTipi,
      bankaAylik: bankaAylik,
      asgariYili: asgari.yil,
      primGunu: primGunu,
      hacizOrani: bankaAylik > 0 ? profil.hacizOrani : 0,
      hacizEtiketi: profil.hacizEtiketi,
    );
  }
}
