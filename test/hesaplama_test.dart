import 'package:flutter_test/flutter_test.dart';
import 'package:puantajim/models/gun_kaydi.dart';
import 'package:puantajim/models/para_hareketi.dart';
import 'package:puantajim/models/profil.dart';
import 'package:puantajim/services/hesaplama.dart';

/// Hakediş hesap kurallarının testleri: `flutter test`
///
/// Eylül 2026: 1 Eylül Salı; pazarlar 6, 13, 20, 27.
void main() {
  String tarih(int y, int a, int g) =>
      '$y-${a.toString().padLeft(2, '0')}-${g.toString().padLeft(2, '0')}';

  /// Bir ayı doldurur: hafta içi + cumartesi "Geldi", pazar "Hafta Tatili".
  /// [degisen] ile belirli günler farklı durumla girilir, [bos] günler hiç girilmez.
  List<GunKaydi> tamAy(int y, int a,
      {Map<int, GunDurumu> degisen = const {},
      Map<int, double> mesai = const {},
      Set<int> bos = const {},
      RaporTuru rapor = RaporTuru.ayakta}) {
    final gunSayisi = DateTime(y, a + 1, 0).day;
    return [
      for (var g = 1; g <= gunSayisi; g++)
        if (!bos.contains(g))
          GunKaydi(
            tarih: tarih(y, a, g),
            durum: degisen[g] ??
                (DateTime(y, a, g).weekday == DateTime.sunday
                    ? GunDurumu.haftaTatili
                    : GunDurumu.geldi),
            mesaiSaat: mesai[g] ?? 0,
            raporTuru: rapor,
          ),
    ];
  }

  AylikOzet hesapla(Profil p, int y, int a, List<GunKaydi> k,
          {List<GunKaydi> onceki = const [],
          List<ParaHareketi> hareketler = const [],
          DateTime? bugun}) =>
      Hesaplama.hesapla(
        profil: p,
        ay: DateTime(y, a),
        kayitlar: k,
        hareketler: hareketler,
        oncekiAyKayitlari: onceki,
        bugun: bugun ?? DateTime(2027, 6, 1), // ay bitmiş sayılsın
      );

  const p = Profil(adSoyad: 'Test', ucret: 45000); // günlük 1.500, saatlik 200

  group('Sadece girilen günler kazandırır', () {
    test('Hiç gün girilmeyen ay: 0 TL', () {
      final o = hesapla(p, 2026, 9, const []);
      expect(o.odenenGun, 0);
      expect(o.temelUcret, 0);
      expect(o.net, 0);
      expect(o.isaretsizGun, 30);
    });

    test('Ay ortası: 10 Eylül\'e kadar girilenler + otomatik pazar', () {
      final k = [
        for (var g = 1; g <= 10; g++)
          if (g != 6) GunKaydi(tarih: tarih(2026, 9, g), durum: GunDurumu.geldi),
      ];
      final o = hesapla(p, 2026, 9, k, bugun: DateTime(2026, 9, 10));
      expect(o.otomatikTatil, 1); // 6 Eylül Pazar otomatik hafta tatili
      expect(o.odenenGun, 10);
      expect(o.temelUcret, 15000);
      expect(o.ayBitti, false);
      expect(o.kesintiGunu, 0); // ay bitmeden eksik gün yazılmaz
    });

    test('Çalışılmayan haftanın pazarı otomatik sayılmaz', () {
      // Sadece 1-5 Eylül geldi; 7-12 boş -> 13 Eylül pazarı sayılmaz
      final k = [
        for (var g = 1; g <= 5; g++)
          GunKaydi(tarih: tarih(2026, 9, g), durum: GunDurumu.geldi),
      ];
      final o = hesapla(p, 2026, 9, k, bugun: DateTime(2026, 9, 14));
      expect(o.otomatikTatilGunleri, {6});
      expect(o.odenenGun, 6);
    });
  });

  group('Her ay 30 gün', () {
    test('30 çeken ay tam: 45.000', () {
      final o = hesapla(p, 2026, 9, tamAy(2026, 9));
      expect(o.odenenGun, 30);
      expect(o.temelUcret, 45000);
    });

    test('31 çeken ay tam: yine 30 gün, 45.000', () {
      final o = hesapla(p, 2026, 10, tamAy(2026, 10));
      expect(o.odenenGun, 30);
      expect(o.temelUcret, 45000);
    });

    test('31 çeken ay, 1 gün gelmedi: gün + o haftanın pazarı kesilir = 29', () {
      final o = hesapla(p, 2026, 10, tamAy(2026, 10, degisen: {5: GunDurumu.gelmedi}));
      expect(o.kesilenPazarGunleri, {11});
      expect(o.odenenGun, 29);
    });

    test('Pazar kesintisi kapalıysa: 31. gün telafi eder, 30 gün', () {
      const pk = Profil(adSoyad: 'Test', ucret: 45000, pazarKesintisi: false);
      final o = hesapla(pk, 2026, 10, tamAy(2026, 10, degisen: {5: GunDurumu.gelmedi}));
      expect(o.odenenGun, 30);
      expect(o.kesilenPazar, 0);
    });

    test('31 çeken ay, aynı haftada 2 gün gelmedi: 28 gün', () {
      final o = hesapla(p, 2026, 10,
          tamAy(2026, 10, degisen: {5: GunDurumu.gelmedi, 6: GunDurumu.gelmedi}));
      expect(o.odenenGun, 28);
      expect(o.temelUcret, 28 * 1500);
    });

    test('Şubat tam: 30 gün; 1 gün gelmedi (+pazar): 28 gün', () {
      expect(hesapla(p, 2027, 2, tamAy(2027, 2)).temelUcret, 45000);
      expect(
          hesapla(p, 2027, 2, tamAy(2027, 2, degisen: {3: GunDurumu.gelmedi}))
              .odenenGun,
          28);
    });

    test('Eksik, yarım gün, mesai, avans, ek ödeme', () {
      final o = hesapla(
        p,
        2026,
        9,
        tamAy(2026, 9,
            degisen: {1: GunDurumu.gelmedi, 2: GunDurumu.gelmedi, 3: GunDurumu.yarimGun},
            mesai: {4: 4, 5: 6}),
        hareketler: const [
          ParaHareketi(id: '1', tarih: '2026-09-10', tur: HareketTuru.avans, tutar: 5000),
          ParaHareketi(id: '2', tarih: '2026-09-15', tur: HareketTuru.ekOdeme, tutar: 1000),
        ],
      );
      // 2 gelmedi + yarım gün (0,5) + 6 Eylül pazarı kesildi = 3,5 gün eksik
      expect(o.kesilenPazarGunleri, {6});
      expect(o.odenenGun, 26.5);
      expect(o.kesintiGunu, 3.5);
      expect(o.temelUcret, 39750);
      expect(o.mesaiUcreti, 10 * 200 * 1.5); // 3.000 (%50 zamlı)
      expect(o.brut, 39750 + 3000 + 1000);
      expect(o.net, 43750 - 5000);
    });
  });

  group('Banka / elden / haciz / rapor', () {
    const bankali = Profil(
        adSoyad: 'Test',
        ucret: 45000,
        bankaTipi: BankaTipi.ozel,
        bankaTutar: 35875.50);

    test('30 gün tam: banka 35.875,50, elden 9.124,50', () {
      final o = hesapla(bankali, 2026, 9, tamAy(2026, 9));
      expect(o.bankaHakedis, closeTo(35875.50, 0.01));
      expect(o.elden, closeTo(9124.50, 0.01));
    });

    test('Haciz 1/4 bankaya yatandan kesilir, elden değişmez', () {
      const ph = Profil(
          adSoyad: 'Test',
          ucret: 45000,
          bankaTipi: BankaTipi.ozel,
          bankaTutar: 35875.50,
          hacizOrani: 0.25);
      final o = hesapla(ph, 2026, 9, tamAy(2026, 9));
      expect(o.haciz, closeTo(8968.875, 0.01));
      expect(o.bankayaYatan, closeTo(26906.625, 0.01));
      expect(o.elden, closeTo(9124.50, 0.01));
    });

    test('2 gün gelmedi (+pazar): banka ve maaş 27 gün üzerinden', () {
      final o = hesapla(bankali, 2026, 9,
          tamAy(2026, 9, degisen: {3: GunDurumu.gelmedi, 4: GunDurumu.gelmedi}));
      expect(o.temelUcret, closeTo(40500, 0.01));
      expect(o.bankaHakedis, closeTo(35875.50 / 30 * 27, 0.01));
      expect(o.elden, closeTo(40500 - 35875.50 / 30 * 27, 0.01));
    });

    test('6 gün ayakta rapor: maaş tam, SGK 4 gün öder, farkı işveren', () {
      final o = hesapla(bankali, 2026, 9,
          tamAy(2026, 9, degisen: {for (var g = 1; g <= 6; g++) g: GunDurumu.raporlu}));
      expect(o.temelUcret, closeTo(45000, 0.01)); // rapor maaştan düşmedi
      expect(o.sgkOdenekGunu, 4); // 3.-6. gün
      expect(o.sgkOdenegi, closeTo(4 * 1101 * 2 / 3, 0.01)); // 2.936
      expect(o.primGunu, 24);
      expect(o.bankaHakedis, closeTo(35875.50 / 30 * 24, 0.01));
      // İşçinin eline geçen toplam = banka + elden + SGK = tam maaş
      expect(o.bankaHakedis + o.elden + o.sgkOdenegi, closeTo(45000, 0.01));
    });

    test('Önceki aydan devam eden rapor: 1 Eylül raporun 3. günü', () {
      final o = hesapla(bankali, 2026, 9,
          tamAy(2026, 9, degisen: {1: GunDurumu.raporlu}),
          onceki: [
            GunKaydi(tarih: tarih(2026, 8, 30), durum: GunDurumu.raporlu),
            GunKaydi(tarih: tarih(2026, 8, 31), durum: GunDurumu.raporlu),
          ]);
      expect(o.sgkOdenekGunu, 1);
    });

    test('Asgari ücret seçiliyse 2026 net asgari bankaya yatar', () {
      const pa = Profil(adSoyad: 'Test', ucret: 45000, bankaTipi: BankaTipi.asgari);
      final o = hesapla(pa, 2026, 9, tamAy(2026, 9));
      expect(o.bankaHakedis, closeTo(28075.50, 0.01));
      expect(o.elden, closeTo(45000 - 28075.50, 0.01));
    });
  });

  group('Pazar çalışması ve mesai zammı', () {
    test('Pazar çalıştı (1\'e 2): tatil ücreti + 2 yevmiye ek', () {
      final o = hesapla(p, 2026, 9, tamAy(2026, 9, degisen: {6: GunDurumu.geldi}));
      expect(o.odenenGun, 30);
      expect(o.pazarCalisilanGun, 1);
      expect(o.pazarCalismaUcreti, 3000);
      expect(o.brut, 48000);
    });

    test('Pazar 1\'e 1,5', () {
      const p15 = Profil(adSoyad: 'Test', ucret: 45000, pazarEkYevmiye: 1.5);
      final o = hesapla(p15, 2026, 9, tamAy(2026, 9, degisen: {6: GunDurumu.geldi}));
      expect(o.pazarCalismaUcreti, 2250);
    });

    test('Pazar çalıştı ama haftada gelmedi: tatil ücreti kesilir, ek yevmiye kalır', () {
      final o = hesapla(p, 2026, 9,
          tamAy(2026, 9, degisen: {6: GunDurumu.geldi, 2: GunDurumu.gelmedi}));
      expect(o.odenenGun, 28);
      expect(o.pazarCalismaUcreti, 3000);
      expect(o.brut, 45000);
    });

    test('Ücretsiz izin mazerettir, pazarı kesmez', () {
      final o = hesapla(p, 2026, 9, tamAy(2026, 9, degisen: {2: GunDurumu.ucretsizIzin}));
      expect(o.kesilenPazar, 0);
      expect(o.odenenGun, 29);
    });

    test('Girilmemiş pazar da kesilir (o hafta gelmedi varsa)', () {
      final o = hesapla(p, 2026, 9,
          tamAy(2026, 9, degisen: {8: GunDurumu.gelmedi}, bos: {13}));
      expect(o.kesilenPazarGunleri, {13});
      expect(o.odenenGun, 28);
    });

    test('Mesai %25: saatlik 200 × 1,25 = 250', () {
      const p25 = Profil(adSoyad: 'Test', ucret: 45000, mesaiKatsayisi: 1.25);
      final o = hesapla(p25, 2026, 9, tamAy(2026, 9, mesai: {4: 2}));
      expect(o.mesaiUcreti, 500);
    });
  });

  test('Giriş-çıkıştan mesai önerisi', () {
    // 08:00-19:00 = 11 saat - 1 mola - 7,5 normal = 2,5 saat
    expect(GunKaydi.mesaiOner('08:00', '19:00', 7.5, 1), 2.5);
    expect(GunKaydi.mesaiOner('08:00', '16:30', 7.5, 1), 0);
    expect(GunKaydi.sureHesapla('20:00', '08:00'), 12);
  });
}
