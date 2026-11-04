import 'package:flutter/material.dart';

import '../models/gun_kaydi.dart';
import '../services/bicim.dart';
import '../services/hesaplama.dart';
import '../services/puantaj_hesaplama_engine.dart';

/// Aylık akıllı takvim.
///
///  - Günler soft/pastel renkli; durum simgeyle gösterilir (lejant gerekmez).
///  - Güne dokununca [onGunSec] çağrılır (çağıran taraf alt paneli açar).
///  - [karsilastirma] verilirse (patron modu: işçinin kendi kaydı) uyuşmayan
///    günlerin etrafına turuncu kesikli çerçeve çizilir.
///  - [ozet] verilirse: kesilen pazar, otomatik hafta tatili ve patron
///    inisiyatifi işaretleri gösterilir.
class AkilliTakvimWidget extends StatelessWidget {
  final DateTime ay;
  final Map<String, GunKaydi> kayitlar;
  final Map<String, GunKaydi>? karsilastirma;
  final AylikOzet? ozet;
  final bool Function(DateTime)? notVar;
  final ValueChanged<DateTime> onGunSec;

  const AkilliTakvimWidget({
    super.key,
    required this.ay,
    required this.kayitlar,
    required this.onGunSec,
    this.karsilastirma,
    this.ozet,
    this.notVar,
  });

  static const _gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const turuncu = Color(0xFFEF6C00);

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    final bosluk = DateTime(ay.year, ay.month, 1).weekday - 1; // Pazartesi = 0
    final bugun = Bicim.sadeceGun(DateTime.now());
    final hucreSayisi = bosluk + gunSayisi;
    final satir = (hucreSayisi / 7).ceil();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: LayoutBuilder(builder: (context, k) {
          // Hücre boyu genişliğe göre: küçük ekranda taşma olmaz
          const aralik = 5.0;
          final hucreGenislik = (k.maxWidth - aralik * 6) / 7;
          final hucreYukseklik = (hucreGenislik * 1.12).clamp(44.0, 74.0).toDouble();
          return Column(
            children: [
              Row(children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _gunler[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: i == 6 ? renk.error.withValues(alpha: 0.8) : renk.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              for (var s = 0; s < satir; s++)
                Padding(
                  padding: EdgeInsets.only(bottom: s == satir - 1 ? 0 : aralik),
                  child: Row(children: [
                    for (var c = 0; c < 7; c++) ...[
                      if (c > 0) const SizedBox(width: aralik),
                      SizedBox(
                        width: hucreGenislik,
                        height: hucreYukseklik,
                        child: () {
                          final g = s * 7 + c - bosluk + 1;
                          if (g < 1 || g > gunSayisi) return const SizedBox.shrink();
                          return _hucre(context, DateTime(ay.year, ay.month, g), bugun, renk);
                        }(),
                      ),
                    ],
                  ]),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _hucre(BuildContext context, DateTime t, DateTime bugun, ColorScheme renk) {
    final anahtar = Bicim.anahtar(t);
    final k = kayitlar[anahtar];
    final bugunMu = t == bugun;
    final gelecek = t.isAfter(bugun);
    final pazar = t.weekday == DateTime.sunday;
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final o = ozet;
    final otomatikTatil = o?.otomatikTatilGunleri.contains(t.day) ?? false;
    final kesildi = o?.kesilenPazarGunleri.contains(t.day) ?? false;
    final inisiyatif = o?.inisiyatifPazarGunleri.contains(t.day) ?? false;
    final not = notVar?.call(t) ?? false;

    // Patron ↔ işçi uyuşmazlığı (sadece bugüne kadar)
    Uyusmazlik? uyusmazlik;
    if (karsilastirma != null && !gelecek) {
      uyusmazlik = PuantajHesaplamaEngine.karsilastir(k, karsilastirma![anahtar]);
      if (uyusmazlik == Uyusmazlik.isciGirmedi) uyusmazlik = null;
    }

    final Color zemin;
    if (k != null) {
      zemin = kesildi && k.durum == GunDurumu.haftaTatili
          ? renk.errorContainer.withValues(alpha: 0.45)
          : k.durum.pastel(koyu: koyu, zemin: renk.surface);
    } else if (kesildi) {
      zemin = renk.errorContainer.withValues(alpha: 0.35);
    } else if (otomatikTatil) {
      zemin = GunDurumu.haftaTatili.pastel(koyu: koyu, zemin: renk.surface);
    } else {
      zemin = renk.surfaceContainerHighest.withValues(alpha: gelecek ? 0.18 : 0.45);
    }

    // Hücrede gösterilecek simge
    IconData? ikon;
    Color? ikonRengi;
    if (kesildi && (k == null || k.durum == GunDurumu.haftaTatili)) {
      ikon = Icons.money_off;
      ikonRengi = renk.error;
    } else if (k != null) {
      ikon = pazar && k.durum == GunDurumu.geldi ? Icons.wb_sunny : k.durum.ikon;
      ikonRengi = k.durum.renk;
    } else if (otomatikTatil) {
      ikon = GunDurumu.haftaTatili.ikon;
      ikonRengi = GunDurumu.haftaTatili.renk.withValues(alpha: 0.55);
    }

    final icerik = Container(
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: BorderRadius.circular(12),
        border: bugunMu ? Border.all(color: renk.primary, width: 2) : null,
      ),
      child: Stack(
        children: [
          if (not)
            const Positioned(
              top: 4,
              right: 4,
              child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFF9A825)),
            ),
          if (inisiyatif)
            Positioned(
              top: 2,
              left: 3,
              child: Icon(Icons.volunteer_activism, size: 11, color: renk.tertiary),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${t.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: bugunMu ? FontWeight.w800 : FontWeight.w600,
                        color: gelecek
                            ? renk.outline
                            : (pazar && k == null && !otomatikTatil
                                ? renk.error.withValues(alpha: 0.8)
                                : null),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 16,
                      child: ikon == null
                          ? null
                          : Icon(ikon, size: 16, color: ikonRengi),
                    ),
                    if (k != null && k.mesaiSaat > 0)
                      Text(
                        '+${Bicim.sayi(k.mesaiSaat)}',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6A1B9A)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: '${t.day} ${Bicim.gunAdi(t)}${k == null ? '' : ', ${k.durum.etiket}'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onGunSec(t),
        child: uyusmazlik == null
            ? icerik
            : CustomPaint(
                foregroundPainter: KesikliCerceve(
                  renk: turuncu,
                  kalinlik: uyusmazlik == Uyusmazlik.farkli ? 2.2 : 1.6,
                  yaricap: 12,
                ),
                child: icerik,
              ),
      ),
    );
  }
}

/// Kesikli (dashed) yuvarlak köşeli çerçeve
class KesikliCerceve extends CustomPainter {
  final Color renk;
  final double kalinlik;
  final double yaricap;
  final double cizgi;
  final double bosluk;

  const KesikliCerceve({
    required this.renk,
    this.kalinlik = 2,
    this.yaricap = 12,
    this.cizgi = 5,
    this.bosluk = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boya = Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalinlik;
    final yarim = kalinlik / 2;
    final yol = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(yarim, yarim, size.width - kalinlik, size.height - kalinlik),
        Radius.circular(yaricap),
      ));
    for (final m in yol.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final son = (d + cizgi).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(d, son), boya);
        d += cizgi + bosluk;
      }
    }
  }

  @override
  bool shouldRepaint(KesikliCerceve eski) =>
      eski.renk != renk || eski.kalinlik != kalinlik || eski.yaricap != yaricap;
}
