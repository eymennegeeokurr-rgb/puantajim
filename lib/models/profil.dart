/// Ücret tipi: aylık maaş (maaş ÷ 30 = günlük) veya günlük yevmiye.
enum UcretTipi { aylik, gunluk }

extension UcretTipiX on UcretTipi {
  String get etiket => this == UcretTipi.aylik ? 'Aylık Maaş' : 'Günlük Yevmiye';
}

/// Uygulamayı kullanan kişinin bilgileri ve hesap ayarları.
/// Uygulama tek kullanıcılıdır: her telefonda bir profil vardır.
class Profil {
  final String adSoyad;
  final String gorev;
  final String firma; // Çalıştığı firma / şantiye (rapor başlığında görünür)
  final UcretTipi ucretTipi;
  final double ucret; // Aylık maaş veya günlük yevmiye

  /// Günlük normal çalışma saati (İş Kanunu: 45 saat / 6 gün = 7,5)
  final double gunlukSaat;

  /// Fazla mesai katsayısı (İş Kanunu: %50 zamlı = 1,5)
  final double mesaiKatsayisi;

  /// Giriş-çıkış saatinden mesai önerirken düşülecek mola (saat)
  final double molaSaat;

  const Profil({
    required this.adSoyad,
    this.gorev = '',
    this.firma = '',
    this.ucretTipi = UcretTipi.aylik,
    required this.ucret,
    this.gunlukSaat = 7.5,
    this.mesaiKatsayisi = 1.5,
    this.molaSaat = 1.0,
  });

  /// Bir günlük ücret karşılığı
  double get gunlukUcret => ucretTipi == UcretTipi.aylik ? ucret / 30 : ucret;

  /// Bir saatlik ücret karşılığı
  double get saatlikUcret => gunlukSaat > 0 ? gunlukUcret / gunlukSaat : 0;

  Map<String, dynamic> toJson() => {
        'adSoyad': adSoyad,
        'gorev': gorev,
        'firma': firma,
        'ucretTipi': ucretTipi.name,
        'ucret': ucret,
        'gunlukSaat': gunlukSaat,
        'mesaiKatsayisi': mesaiKatsayisi,
        'molaSaat': molaSaat,
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
      );
}
