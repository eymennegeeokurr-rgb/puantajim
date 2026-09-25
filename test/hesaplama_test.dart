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
