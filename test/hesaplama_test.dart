import 'package:flutter_test/flutter_test.dart';
import 'package:puantajim/models/gun_kaydi.dart';
import 'package:puantajim/models/para_hareketi.dart';
import 'package:puantajim/models/profil.dart';
import 'package:puantajim/services/hesaplama.dart';

/// Hakediş hesap kurallarının testleri: `flutter test`
void main() {
  final eylul = DateTime(2026, 9);
  final ayBitti = DateTime(2026, 10, 5);

  GunKaydi g(int gun, GunDurumu d, [double mesai = 0]) => GunKaydi(
      tarih: '2026-09-${gun.toString().padLeft(2, '0')}',
      durum: d,
      mesaiSaat: mesai);

  test('Aylıkçı: 45.000 maaş, 2 gün gelmedi, 1 yarım gün, 10 saat mesai', () {
    const p = Profil(adSoyad: 'Test', ucret: 45000); // aylık, 7,5 sa, ×1,5
    final o = Hesaplama.hesapla(
      profil: p,
      ay: eylul,
      kayitlar: [
        g(1, GunDurumu.gelmedi),
        g(2, GunDurumu.gelmedi),
        g(3, GunDurumu.yarimGun),
        g(4, GunDurumu.geldi, 4),
        g(5, GunDurumu.geldi, 6),
        g(6, GunDurumu.haftaTatili),
      ],
      hareketler: const [
        ParaHareketi(id: '1', tarih: '2026-09-10', tur: HareketTuru.avans, tutar: 5000),
        ParaHareketi(id: '2', tarih: '2026-09-15', tur: HareketTuru.ekOdeme, tutar: 1000),
      ],
      bugun: ayBitti,
    );
    expect(o.gunlukUcret, 1500);
    expect(o.kesintiGunu, 2.5);
    expect(o.temelUcret, 45000 - 2.5 * 1500); // 41.250
    expect(o.saatlikUcret, 200);
    expect(o.mesaiUcreti, 10 * 200 * 1.5); // 3.000
    expect(o.brut, 41250 + 3000 + 1000);
    expect(o.net, 45250 - 5000);
    expect(o.isaretsizGun, 30 - 6);
  });

  group('Aylıkçı her ay 30 gün üzerinden', () {
    const p = Profil(adSoyad: 'Test', ucret: 45000);
    GunKaydi e(int y, int a, int g, GunDurumu d) => GunKaydi(
        tarih:
            '$y-${a.toString().padLeft(2, '0')}-${g.toString().padLeft(2, '0')}',
        durum: d);
    AylikOzet h(int y, int a, List<GunKaydi> k) => Hesaplama.hesapla(
        profil: p,
        ay: DateTime(y, a),
        kayitlar: k,
        hareketler: const [],
        bugun: DateTime(2027, 1, 1));

    test('31 çeken ay, 31 gün geldi: yine 30 gün (tam maaş)', () {
      final o = h(2026, 10, [for (var g = 1; g <= 31; g++) e(2026, 10, g, GunDurumu.geldi)]);
      expect(o.odenenGun, 30);
      expect(o.temelUcret, 45000);
    });

    test('31 çeken ay, 1 gün gelmedi: 31. gün telafi eder, tam maaş', () {
      final o = h(2026, 10, [e(2026, 10, 5, GunDurumu.gelmedi)]);
      expect(o.odenenGun, 30);
      expect(o.kesintiGunu, 0);
      expect(o.temelUcret, 45000);
    });

    test('31 çeken ay, 2 gün gelmedi: 29 gün', () {
      final o = h(2026, 10, [
        e(2026, 10, 5, GunDurumu.gelmedi),
        e(2026, 10, 6, GunDurumu.gelmedi),
      ]);
      expect(o.odenenGun, 29);
      expect(o.temelUcret, 29 * 1500);
    });

    test('Şubat tam çalıştı: 30 gün (tam maaş); 1 gün gelmedi: 29 gün', () {
      expect(h(2027, 2, const []).temelUcret, 45000);
      expect(h(2027, 2, [e(2027, 2, 3, GunDurumu.gelmedi)]).odenenGun, 29);
    });
  });

  group('Banka / elden / haciz / rapor', () {
    GunKaydi e(int a, int g, GunDurumu d, [RaporTuru r = RaporTuru.ayakta]) =>
        GunKaydi(
            tarih: '2026-${a.toString().padLeft(2, '0')}-${g.toString().padLeft(2, '0')}',
            durum: d,
            raporTuru: r);
    AylikOzet h(Profil p, List<GunKaydi> k, {List<GunKaydi> onceki = const []}) =>
        Hesaplama.hesapla(
            profil: p,
            ay: DateTime(2026, 9),
            kayitlar: k,
            hareketler: const [],
            oncekiAyKayitlari: onceki,
            bugun: DateTime(2026, 10, 5));

    const bankali = Profil(
        adSoyad: 'Test',
        ucret: 45000,
        bankaTipi: BankaTipi.ozel,
        bankaTutar: 35875.50);

    test('30 gün tam: banka 35.875,50, elden 9.124,50', () {
      final o = h(bankali, const []);
      expect(o.bankaHakedis, closeTo(35875.50, 0.01));
      expect(o.elden, closeTo(9124.50, 0.01));
    });

    test('Haciz 1/4 bankaya yatandan kesilir, elden değişmez', () {
      const p = Profil(
          adSoyad: 'Test',
          ucret: 45000,
          bankaTipi: BankaTipi.ozel,
          bankaTutar: 35875.50,
          hacizOrani: 0.25);
      final o = h(p, const []);
      expect(o.haciz, closeTo(8968.875, 0.01));
      expect(o.bankayaYatan, closeTo(26906.625, 0.01));
      expect(o.elden, closeTo(9124.50, 0.01));
    });

    test('2 gün gelmedi: banka ve maaş 28 gün üzerinden', () {
      final o = h(bankali, [e(9, 3, GunDurumu.gelmedi), e(9, 4, GunDurumu.gelmedi)]);
      expect(o.temelUcret, closeTo(42000, 0.01));
      expect(o.bankaHakedis, closeTo(35875.50 / 30 * 28, 0.01));
      expect(o.elden, closeTo(42000 - 35875.50 / 30 * 28, 0.01));
    });

    test('6 gün ayakta rapor: maaş tam, SGK 4 gün öder, farkı işveren', () {
      final o = h(bankali, [for (var g = 1; g <= 6; g++) e(9, g, GunDurumu.raporlu)]);
      expect(o.temelUcret, closeTo(45000, 0.01)); // rapor maaştan düşmedi
      expect(o.sgkOdenekGunu, 4); // 3.-6. gün
      expect(o.sgkOdenegi, closeTo(4 * 1101 * 2 / 3, 0.01)); // 2.936
      expect(o.primGunu, 24);
      expect(o.bankaHakedis, closeTo(35875.50 / 30 * 24, 0.01));
      // İşçinin eline geçen toplam = banka + elden + SGK = tam maaş
      expect(o.bankaHakedis + o.elden + o.sgkOdenegi, closeTo(45000, 0.01));
    });

    test('Önceki aydan devam eden rapor: 1 Eylül raporun 3. günü', () {
      final o = h(bankali, [e(9, 1, GunDurumu.raporlu)],
          onceki: [e(8, 30, GunDurumu.raporlu), e(8, 31, GunDurumu.raporlu)]);
      expect(o.sgkOdenekGunu, 1);
    });

    test('Asgari ücret seçiliyse 2026 net asgari bankaya yatar', () {
      const p = Profil(adSoyad: 'Test', ucret: 45000, bankaTipi: BankaTipi.asgari);
      final o = h(p, const []);
      expect(o.bankaHakedis, closeTo(28075.50, 0.01));
      expect(o.elden, closeTo(45000 - 28075.50, 0.01));
    });
  });

  test('Yevmiyeci: 1.200 TL, 20 gün + 2 yarım + 1 ücretli izin', () {
    const p = Profil(adSoyad: 'Test', ucret: 1200, ucretTipi: UcretTipi.gunluk);
    final kayitlar = [
      for (var i = 1; i <= 20; i++) g(i, GunDurumu.geldi),
      g(21, GunDurumu.yarimGun),
      g(22, GunDurumu.yarimGun),
      g(23, GunDurumu.ucretliIzin),
      g(24, GunDurumu.gelmedi),
      g(25, GunDurumu.haftaTatili),
    ];
    final o = Hesaplama.hesapla(
        profil: p, ay: eylul, kayitlar: kayitlar, hareketler: const [], bugun: ayBitti);
    expect(o.odenenGun, 22);
    expect(o.temelUcret, 22 * 1200);
    expect(o.net, 26400);
  });

  test('Giriş-çıkıştan mesai önerisi', () {
    // 08:00-19:00 = 11 saat - 1 mola - 7,5 normal = 2,5 saat
    expect(GunKaydi.mesaiOner('08:00', '19:00', 7.5, 1), 2.5);
    // Normal gün: mesai yok
    expect(GunKaydi.mesaiOner('08:00', '16:30', 7.5, 1), 0);
    // Gece vardiyası 20:00-08:00 = 12 saat
    expect(GunKaydi.sureHesapla('20:00', '08:00'), 12);
  });
}
