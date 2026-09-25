/// Ücret tipi: aylık maaş (maaş ÷ 30 = günlük) veya günlük yevmiye.
/// (Uygulama aylıkçı çalışanlar içindir; yevmiye eski kayıtlarla uyum için duruyor.)
enum UcretTipi { aylik, gunluk }

extension UcretTipiX on UcretTipi {
  String get etiket => this == UcretTipi.aylik ? 'Aylık Maaş' : 'Günlük Yevmiye';
}

/// Maaşın bankaya yatan kısmı nasıl belirlenir?
enum BankaTipi {
  /// Bankaya bir şey yatmaz, hepsi elden
  yok,

  /// O yılın net asgari ücreti bankaya yatar
  asgari,

  /// Firma ile anlaşılan sabit tutar bankaya yatar
  ozel,
}

extension BankaTipiX on BankaTipi {
  String get etiket => const {
        BankaTipi.yok: 'Hepsi elden',
        BankaTipi.asgari: 'Asgari ücret',
        BankaTipi.ozel: 'Anlaşılan tutar',
      }[this]!;

  static BankaTipi adindan(String? ad) => BankaTipi.values
      .firstWhere((t) => t.name == ad, orElse: () => BankaTipi.yok);
}

/// Uygulamayı kullanan kişinin bilgileri ve hesap ayarları.
/// Uygulama tek kullanıcılıdır: her telefonda bir profil vardır.
class Profil {
  final String adSoyad;
  final String gorev;
  final String firma; // Çalıştığı firma / şantiye (rapor başlığında görünür)
  final UcretTipi ucretTipi;
  final double ucret; // Aylık toplam maaş (banka + elden)

  /// Günlük normal çalışma saati (İş Kanunu: 45 saat / 6 gün = 7,5)
  final double gunlukSaat;

  /// Fazla mesai katsayısı (İş Kanunu: %50 zamlı = 1,5)
  final double mesaiKatsayisi;

  /// Giriş-çıkış saatinden mesai önerirken düşülecek mola (saat)
  final double molaSaat;

  // ---- Pazar ----

  /// Pazar çalışana, hafta tatili ücretine EK olarak ödenen yevmiye.
  /// 1'e 1 = 1, 1'e 1,5 = 1.5, 1'e 2 = 2 (varsayılan)
  final double pazarEkYevmiye;

  /// true: Haftada mazeretsiz "Gelmedim" varsa o haftanın pazar ücreti kesilir
  final bool pazarKesintisi;

  // ---- Banka / elden ----

  /// Bankaya yatan kısım: yok / asgari ücret / anlaşılan tutar
  final BankaTipi bankaTipi;

  /// Anlaşılan tutar seçiliyse: 30 gün için bankaya yatan NET tutar
  final double bankaTutar;

  /// Haciz (icra) kesinti oranı: 0 = yok, 0.25 = dörtte bir, 0.10 = onda bir.
  /// Bankaya yatan tutardan kesilir.
  final double hacizOrani;

  // ---- Rapor ----

  /// true: Raporlu günlerde maaş kesilmez; SGK'nın ödediği rapor parası
  /// düşülür, aradaki farkı işveren maaş üzerinden öder.
  /// false: Raporlu günler maaştan düşülür, sadece SGK öder.
  final bool raporTamOdenir;

  /// SGK'ya bildirilen 30 günlük BRÜT kazanç (rapor parası hesabı için).
  /// 0 ise o yılın brüt asgari ücreti kullanılır.
  final double sgkBrut;

  const Profil({
    required this.adSoyad,
    this.gorev = '',
    this.firma = '',
    this.ucretTipi = UcretTipi.aylik,
    required this.ucret,
    this.gunlukSaat = 7.5,
    this.mesaiKatsayisi = 1.5,
    this.molaSaat = 1.0,
    this.pazarEkYevmiye = 2,
    this.pazarKesintisi = true,
    this.bankaTipi = BankaTipi.yok,
    this.bankaTutar = 0,
    this.hacizOrani = 0,
    this.raporTamOdenir = true,
    this.sgkBrut = 0,
  });

  /// Bir günlük ücret karşılığı
  double get gunlukUcret => ucretTipi == UcretTipi.aylik ? ucret / 30 : ucret;

  /// Bir saatlik ücret karşılığı
  double get saatlikUcret => gunlukSaat > 0 ? gunlukUcret / gunlukSaat : 0;

  /// "1'e 2" gibi pazar oranı yazısı
  String get pazarEtiketi {
    final v = pazarEkYevmiye;
    return "1'e ${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',')}";
  }

  /// "%50" gibi fazla mesai zammı yazısı
  String get mesaiZamEtiketi => '%${((mesaiKatsayisi - 1) * 100).round()}';

  /// Haciz oranının yazısı
  String get hacizEtiketi {
    if (hacizOrani >= 0.249 && hacizOrani <= 0.251) return '1/4';
    if (hacizOrani >= 0.099 && hacizOrani <= 0.101) return '1/10';
    return '%${(hacizOrani * 100).toStringAsFixed(0)}';
  }

  Map<String, dynamic> toJson() => {
        'adSoyad': adSoyad,
        'gorev': gorev,
        'firma': firma,
        'ucretTipi': ucretTipi.name,
        'ucret': ucret,
        'gunlukSaat': gunlukSaat,
        'mesaiKatsayisi': mesaiKatsayisi,
        'molaSaat': molaSaat,
        'pazarEkYevmiye': pazarEkYevmiye,
        'pazarKesintisi': pazarKesintisi,
        'bankaTipi': bankaTipi.name,
        'bankaTutar': bankaTutar,
        'hacizOrani': hacizOrani,
        'raporTamOdenir': raporTamOdenir,
        'sgkBrut': sgkBrut,
      };

  factory Profil.fromJson(Map<String, dynamic> j) => Profil(
        adSoyad: (j['adSoyad'] as String?) ?? '',
        gorev: (j['gorev'] as String?) ?? '',
        firma: (j['firma'] as String?) ?? '',
        ucretTipi:
            j['ucretTipi'] == 'gunluk' ? UcretTipi.gunluk : UcretTipi.aylik,
        ucret: (j['ucret'] as num?)?.toDouble() ?? 0,
        gunlukSaat: (j['gunlukSaat'] as num?)?.toDouble() ?? 7.5,
        mesaiKatsayisi: (j['mesaiKatsayisi'] as num?)?.toDouble() ?? 1.5,
        molaSaat: (j['molaSaat'] as num?)?.toDouble() ?? 1.0,
        pazarEkYevmiye: (j['pazarEkYevmiye'] as num?)?.toDouble() ?? 2,
        pazarKesintisi: (j['pazarKesintisi'] as bool?) ?? true,
        bankaTipi: BankaTipiX.adindan(j['bankaTipi'] as String?),
        bankaTutar: (j['bankaTutar'] as num?)?.toDouble() ?? 0,
        hacizOrani: (j['hacizOrani'] as num?)?.toDouble() ?? 0,
        raporTamOdenir: (j['raporTamOdenir'] as bool?) ?? true,
        sgkBrut: (j['sgkBrut'] as num?)?.toDouble() ?? 0,
      );
}
