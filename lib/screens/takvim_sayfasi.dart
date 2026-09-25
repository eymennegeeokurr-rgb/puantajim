import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/gun_kaydi.dart';
import '../services/bicim.dart';
import '../services/hesaplama.dart';
import '../widgets/ay_gezgini.dart';
import '../widgets/kurulum_ipucu.dart';
import 'gun_duzenle_sayfasi.dart';

/// Ana ekran: bugün hızlı giriş + aylık takvim + ay özeti.
class TakvimSayfasi extends StatelessWidget {
  const TakvimSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: depo,
          builder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Puantajım'),
              Text(
                depo.profil?.adSoyad ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([depo, depo.seciliAy]),
        builder: (context, _) {
          final ay = depo.seciliAy.value;
          final simdi = DateTime.now();
          final buAy = ay.year == simdi.year && ay.month == simdi.month;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const KurulumIpucu(),
              const AyGezgini(),
              if (buAy) _BugunKarti(tarih: Bicim.sadeceGun(simdi)),
              _TakvimIzgarasi(ay: ay),
              const _Lejant(),
              _AyOzetiKarti(ay: ay),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Bugün kartı: tek dokunuşla "Geldim / Gelmedim"
// =============================================================================

class _BugunKarti extends StatelessWidget {
  final DateTime tarih;
  const _BugunKarti({required this.tarih});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    final renk = Theme.of(context).colorScheme;
    final k = depo.gun(tarih);

    Future<void> hizli(GunDurumu d) async {
      final mevcut = depo.gun(tarih);
      final GunKaydi yeni;
      if (mevcut == null) {
        yeni = GunKaydi(tarih: Bicim.anahtar(tarih), durum: d);
      } else if (d.mesaiGirilebilir) {
        yeni = mevcut.copyWith(durum: d); // saat ve mesai korunur
      } else {
        yeni = GunKaydi(tarih: mevcut.tarih, durum: d, not: mevcut.not);
      }
      await depo.gunKaydet(yeni);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Bugün: ${d.etiket}'),
          action: SnackBarAction(
              label: 'Detay', onPressed: () => gunDuzenle(context, tarih)),
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Bugün • ${Bicim.gunAy(tarih)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (k != null)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(k.durum.ikon, size: 16, color: k.durum.renk),
                  label: Text(k.mesaiSaat > 0
                      ? '${k.durum.etiket} +${Bicim.sayi(k.mesaiSaat)} sa'
                      : k.durum.etiket),
                ),
            ]),
            const SizedBox(height: 8),
            if (k == null)
              Text('Bugün için henüz kayıt girmediniz.',
                  style: TextStyle(color: renk.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => hizli(GunDurumu.geldi),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Geldim'),
                  style: FilledButton.styleFrom(
                    backgroundColor: GunDurumu.geldi.renk,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => hizli(GunDurumu.gelmedi),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Gelmedim'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GunDurumu.gelmedi.renk,
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Mesai, saat, izin...',
                onPressed: () => gunDuzenle(context, tarih),
                icon: const Icon(Icons.edit_note),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Aylık takvim ızgarası
// =============================================================================

class _TakvimIzgarasi extends StatelessWidget {
  final DateTime ay;
  const _TakvimIzgarasi({required this.ay});

  static const _gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    final bosluk = DateTime(ay.year, ay.month, 1).weekday - 1; // Pazartesi = 0
    final bugun = Bicim.sadeceGun(DateTime.now());

    // Girilmemiş ama otomatik hafta tatili sayılan pazarlar (soluk "HT" gösterilir)
    final depo = Depo.instance;
    final profil = depo.profil;
    final ozet = profil == null
        ? null
        : Hesaplama.hesapla(
            profil: profil,
            ay: ay,
            kayitlar: depo.ayKayitlari(ay),
            hareketler: const [],
            oncekiAyKayitlari: depo.ayKayitlari(DateTime(ay.year, ay.month - 1)),
          );
    final otoTatil = ozet?.otomatikTatilGunleri ?? const <int>{};
    final kesilen = ozet?.kesilenPazarGunleri ?? const <int>{};
    final pazarEtiketi = profil?.pazarEtiketi ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _gunler[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: i == 6 ? renk.error : renk.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.78,
              children: [
                for (var i = 0; i < bosluk; i++) const SizedBox.shrink(),
                for (var g = 1; g <= gunSayisi; g++)
                  _hucre(context, DateTime(ay.year, ay.month, g), bugun, renk,
                      otoTatil.contains(g), kesilen.contains(g), pazarEtiketi),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hucre(BuildContext context, DateTime t, DateTime bugun, ColorScheme renk,
      bool otomatikTatil, bool pazarKesildi, String pazarEtiketi) {
    final k = Depo.instance.gun(t);
    final notVar = Depo.instance.notVar(t);
    final bugunMu = t == bugun;
    final gelecek = t.isAfter(bugun);
    final pazar = t.weekday == DateTime.sunday;

    final zemin = k != null
        ? k.durum.renk.withValues(alpha: 0.18)
        : otomatikTatil
            ? GunDurumu.haftaTatili.renk.withValues(alpha: 0.08)
            : renk.surfaceContainerHighest.withValues(alpha: gelecek ? 0.15 : 0.45);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => gunDuzenle(context, t),
      child: Container(
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: BorderRadius.circular(10),
          border: bugunMu ? Border.all(color: renk.primary, width: 2) : null,
        ),
        child: Stack(
          children: [
            // Not yazılmış günlerde sağ üstte küçük not işareti
            if (notVar)
              const Positioned(
                top: 3,
                right: 3,
                child: Icon(Icons.sticky_note_2, size: 10, color: Color(0xFFF9A825)),
              ),
            Center(
              child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${t.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: bugunMu ? FontWeight.w800 : FontWeight.w600,
                color: gelecek
                    ? renk.outline
                    : (pazar && k == null && !otomatikTatil ? renk.error : null),
              ),
            ),
            const SizedBox(height: 2),
            if (pazarKesildi && (k == null || k.durum == GunDurumu.haftaTatili))
              Text(
                'HT✕',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: renk.error.withValues(alpha: 0.8)),
              )
            else if (k == null && otomatikTatil)
              Text(
                'HT',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: GunDurumu.haftaTatili.renk.withValues(alpha: 0.6)),
              ),
            if (k != null && !(pazarKesildi && k.durum == GunDurumu.haftaTatili))
              Text(
                pazar && k.durum == GunDurumu.geldi ? pazarEtiketi.replaceAll("'e ", ':') : k.durum.kisa,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: k.durum.renk),
              ),
            if (k != null && k.mesaiSaat > 0)
              Text(
                '+${Bicim.sayi(k.mesaiSaat)}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6A1B9A)),
              ),
          ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lejant extends StatelessWidget {
  const _Lejant();

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final d in GunDurumu.values)
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${d.kisa} ',
                  style: TextStyle(fontWeight: FontWeight.w800, color: d.renk)),
              TextSpan(text: d.raporEtiketi),
            ]), style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
          Text.rich(TextSpan(children: [
            const TextSpan(
                text: '+2 ',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF6A1B9A))),
            const TextSpan(text: 'Mesai saati'),
          ]), style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: 'HT✕ ',
                style: TextStyle(fontWeight: FontWeight.w800, color: renk.error)),
            const TextSpan(text: 'Pazar kesildi'),
          ]), style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
          Text.rich(const TextSpan(children: [
            WidgetSpan(
                child: Icon(Icons.sticky_note_2, size: 11, color: Color(0xFFF9A825))),
            TextSpan(text: ' Not var'),
          ]), style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// =============================================================================
// Ay özeti
// =============================================================================

class _AyOzetiKarti extends StatelessWidget {
  final DateTime ay;
  const _AyOzetiKarti({required this.ay});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    final profil = depo.profil;
    if (profil == null) return const SizedBox.shrink();
    final renk = Theme.of(context).colorScheme;
    final o = Hesaplama.hesapla(
      profil: profil,
      ay: ay,
      kayitlar: depo.ayKayitlari(ay),
      hareketler: depo.ayHareketleri(ay),
      oncekiAyKayitlari: depo.ayKayitlari(DateTime(ay.year, ay.month - 1)),
    );

    Widget kutu(String baslik, String deger) => Expanded(
          child: Column(children: [
            Text(deger,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(baslik,
                style: TextStyle(fontSize: 11.5, color: renk.onSurfaceVariant)),
          ]),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              kutu('Ödenecek gün', '${Bicim.sayi(o.odenenGun)}/30'),
              kutu('Mesai (saat)', Bicim.sayi(o.mesaiSaat)),
              kutu('Avans', Bicim.para(o.avans)),
            ]),
            const Divider(height: 22),
            Row(children: [
              Expanded(
                child: Text(o.ayBitti ? 'Kalan alacağım' : 'Şu ana kadarki alacağım',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(Bicim.para(o.net),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: renk.primary)),
            ]),
            if (o.bankaVar) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.account_balance, size: 15, color: renk.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Banka ${Bicim.para(o.bankayaYatan)}'
                    '${o.hacizOrani > 0 ? ' (haciz ${Bicim.para(o.haciz)})' : ''}'
                    '  •  Elden ${Bicim.para(o.elden)}',
                    style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
                  ),
                ),
              ]),
            ],
            if (o.isaretsizGun > 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.info_outline, size: 16, color: renk.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${o.isaretsizGun} geçmiş gün girilmedi (ücrete sayılmaz).',
                    style: TextStyle(fontSize: 12.5, color: renk.error),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
