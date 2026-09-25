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
  final int isaretsizGun; // Bugüne kadar hiç girilmemiş gün (otomatik pazarlar hariç)
  /// Girilmemiş ama otomatik hafta tatili sayılan pazarlar (ayın günü)
  final Set<int> otomatikTatilGunleri;
  final bool ayBitti; // Ay sona erdi mi? (devam eden ayda "şu ana kadar" hesap)
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

  // ---- Pazar ----
  final double pazarCalisilanGun; // Pazar "Geldim" (yarım: 0,5)
  final double pazarEkYevmiye; // Çalışılan her pazar için ek yevmiye (1, 1,5, 2)
  final Set<int> kesilenPazarGunleri; // Mazeretsiz devamsızlık nedeniyle kesilen pazarlar
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
    required this.otomatikTatilGunleri,
    required this.ayBitti,
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
    required this.pazarCalisilanGun,
    required this.pazarEkYevmiye,
    required this.kesilenPazarGunleri,
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

  /// Otomatik sayılan hafta tatili adedi
  int get otomatikTatil => otomatikTatilGunleri.length;

  /// Çalışılan gün (geldi + yarım × 0,5)
  double get calisilanGun =>
      adet(GunDurumu.geldi) + adet(GunDurumu.yarimGun) * 0.5;

  /// Eksik gün kesintisi tutarı
  double get devamsizlikTutari => kesintiGunu * gunlukUcret;

  /// Pazar çalışması ek ücreti
  double get pazarCalismaUcreti => pazarCalisilanGun * pazarEkYevmiye * gunlukUcret;

  /// Kesilen pazar sayısı
  int get kesilenPazar => kesilenPazarGunleri.length;

  /// Toplam hak: temel ücret + mesai + pazar çalışması + ek ödemeler
  double get brut => temelUcret + mesaiUcreti + pazarCalismaUcreti + ekOdeme;

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
///   SADECE GİRİLEN GÜNLER KAZANDIRIR:
///     Geldi, Ücretli İzin, Hafta Tatili, Resmi Tatil = 1 gün; Yarım gün = 0,5
///     Raporlu = 1 gün ("rapor tam ödenir" açıksa), değilse 0
///     Gelmedi, Ücretsiz İzin, girilmemiş gün, gelecek gün = 0
///     Girilmemiş Pazar: o hafta en az bir gün çalışıldıysa otomatik hafta tatili (1)
///   Ödenen gün   = toplam (en fazla 30; 31 çeken ayda 31. gün fazladan para getirmez;
///                  Şubat'ta ay sonuna kadar çalışan 30 güne tamamlanır)
///   PAZAR: Hafta tatili ücreti (1 gün) çalışsa da çalışmasa da ödenir; o hafta
///     mazeretsiz "Gelmedim" varsa kesilir (ayar açıksa). Pazar çalışana ayrıca
///     ek yevmiye (1'e 1 / 1'e 1,5 / 1'e 2) ödenir.
///   Günlük       = maaş ÷ 30,  Temel = ödenen gün × günlük
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
///   Prim günü    = ödenen gün hesabının aynısı, ama raporlu günler 0 sayılır
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
    double mesai = 0, odenenGunlukte = 0;
    var raporGunu = 0;
    final harita = <String, GunKaydi>{};

    for (final k in kayitlar) {
      sayac[k.durum] = (sayac[k.durum] ?? 0) + 1;
      mesai += k.mesaiSaat;
      odenenGunlukte += k.durum.gunlukOdenenGun;
      harita[k.tarih] = k;
      if (k.durum == GunDurumu.raporlu) raporGunu++;
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
    final oncekiHarita = {for (final k in oncekiAyKayitlari) k.tarih: k};
    GunKaydi? kayitBul(DateTime t) =>
        harita[_anahtar(t)] ?? oncekiHarita[_anahtar(t)];

    // O hafta (Pzt-Cmt) en az bir gün çalışıldıysa, girilmemiş Pazar
    // otomatik "hafta tatili" (ücretli) sayılır.
    bool haftadaCalisti(DateTime pazar) {
      for (var i = 1; i <= 6; i++) {
        final k = kayitBul(DateTime(pazar.year, pazar.month, pazar.day - i));
        if (k != null && k.durum.haftaTatiliHakkiVerir) return true;
      }
      return false;
    }

    // O haftada (Pzt-Cmt) mazeretsiz devamsızlık ("Gelmedim") var mı?
    bool haftadaGelmedi(DateTime pazar) {
      for (var i = 1; i <= 6; i++) {
        final k = kayitBul(DateTime(pazar.year, pazar.month, pazar.day - i));
        if (k != null && k.durum == GunDurumu.gelmedi) return true;
      }
      return false;
    }

    // ---- Gün gün: ücret ödenen gün ve SGK prim günü
    // Sadece GİRİLEN günler kazandırır. Girilmemiş günler ve gelecek günler
    // sayılmaz (ay devam ederken "şu ana kadar" hakediş görünür).
    //
    // PAZAR:
    //  - Hafta tatili ücreti (1 gün): çalışsa da çalışmasa da ödenir.
    //    Ancak o hafta mazeretsiz "Gelmedim" varsa kesilir (ayar açıksa).
    //  - Pazar çalıştıysa ("Geldim"): ayrıca [pazarEkYevmiye] kadar ek yevmiye.
    double ucretliToplam = 0, primToplam = 0, pazarCalisma = 0;
    final otomatikTatil = <int>{};
    final kesilenPazar = <int>{};
    var isaretsiz = 0;
    var sonGunOdendi = false;
    for (var g = 1; g <= gunSayisi; g++) {
      final t = DateTime(ay.year, ay.month, g);
      final k = harita[_anahtar(t)];
      final pazar = t.weekday == DateTime.sunday;
      final pazarKesilir = pazar && profil.pazarKesintisi && haftadaGelmedi(t);
      double ucretli = 0, prim = 0;

      if (pazar && (k == null || k.durum.pazarTatilUcretiAlir)) {
        if (k == null && t.isAfter(bugunGun)) {
          // gelecek pazar: henüz hak edilmedi
        } else if (k == null && !haftadaCalisti(t) && !pazarKesilir) {
          isaretsiz++; // hiç çalışılmayan haftanın girilmemiş pazarı
        } else if (pazarKesilir) {
          kesilenPazar.add(g); // mazeretsiz devamsızlık: hafta tatili ücreti yok
        } else {
          ucretli = 1;
          prim = 1;
          if (k == null) otomatikTatil.add(g);
        }
        // Pazar çalışması ek yevmiyesi (tatil ücreti kesilse bile ödenir)
        if (k != null && k.durum == GunDurumu.geldi) pazarCalisma += 1;
        if (k != null && k.durum == GunDurumu.yarimGun) pazarCalisma += 0.5;
      } else if (k != null) {
        ucretli = k.durum.aylikOdenenGun(raporTam: profil.raporTamOdenir);
        prim = k.durum.aylikOdenenGun(raporTam: false);
      } else if (!t.isAfter(bugunGun)) {
        isaretsiz++;
      }
      ucretliToplam += ucretli;
      primToplam += prim;
      if (g == gunSayisi) sonGunOdendi = ucretli > 0 || (k != null && k.durum.pazarTatilUcretiAlir);
    }

    // Her ay 30 gün: 31 çeken ayda 31. gün fazladan para getirmez (en fazla 30);
    // Şubat gibi kısa aylarda ay sonuna kadar çalışan 30 güne tamamlanır.
    double otuzGune(double gun) {
      var v = gun;
      if (gunSayisi < 30 && sonGunOdendi) v += 30 - gunSayisi;
      if (v > 30) v = 30;
      if (v < 0) v = 0;
      return v;
    }

    final ayBitti = bugunGun.isAfter(DateTime(ay.year, ay.month, gunSayisi));
    final double temel;
    final double odenenGun;
    final double kesintiGunu;
    if (aylik) {
      odenenGun = otuzGune(ucretliToplam);
      // Eksik gün sadece ay bitince anlamlı (ay devam ederken gelecek günler eksik değildir)
      kesintiGunu = ayBitti ? 30 - odenenGun : 0;
      temel = odenenGun * gunluk;
    } else {
      kesintiGunu = 0;
      odenenGun = odenenGunlukte;
      temel = odenenGunlukte * gunluk;
    }

    // ---- SGK rapor parası (tahmini)
    // Rapor ardışık günlerden oluşur; önceki aydan devam eden rapor da sayılır
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
    final primGunu = otuzGune(primToplam);

    return AylikOzet(
      ay: ayBasi,
      gunSayisi: gunSayisi,
      sayac: sayac,
      isaretsizGun: isaretsiz,
      otomatikTatilGunleri: otomatikTatil,
      ayBitti: ayBitti,
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
      pazarCalisilanGun: pazarCalisma,
      pazarEkYevmiye: profil.pazarEkYevmiye,
      kesilenPazarGunleri: kesilenPazar,
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
