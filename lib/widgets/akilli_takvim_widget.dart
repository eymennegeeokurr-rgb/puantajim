import 'package:flutter/material.dart';

import '../models/gun_kaydi.dart';
import '../services/bicim.dart';
import '../services/hesaplama.dart';
import '../services/puantaj_hesaplama_engine.dart';
import '../tema.dart';

/// Takvimde bir günün nokta rengi
Color takvimNoktaRengi(GunDurumu d) {
  switch (d) {
    case GunDurumu.geldi:
    case GunDurumu.yarimGun:
      return Renkler.yesil;
    case GunDurumu.haftaTatili:
      return Renkler.gri;
    default:
      return d.renk;
  }
}

/// Aylık akıllı takvim.
///
///  - Her gün yuvarlak; altında durum noktası (yeşil çalışıldı, gri hafta tatili,
///    turuncu eksik kayıt, diğer durumlar kendi rengiyle).
///  - Önceki / sonraki ayın günleri soluk gösterilir.
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
  final bool lejant;

  const AkilliTakvimWidget({
    super.key,
    required this.ay,
    required this.kayitlar,
    required this.onGunSec,
    this.karsilastirma,
    this.ozet,
    this.notVar,
    this.lejant = true,
  });

  static const _gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const turuncu = Color(0xFFEF6C00);

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final ilk = DateTime(ay.year, ay.month, 1);
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    final bosluk = ilk.weekday - 1; // Pazartesi = 0
    final bugun = Bicim.sadeceGun(DateTime.now());
    final satir = ((bosluk + gunSayisi) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: LayoutBuilder(builder: (context, k) {
        final hucreGenislik = k.maxWidth / 7;
        final hucreYukseklik = (hucreGenislik * 1.08).clamp(46.0, 66.0).toDouble();
        return Column(
          children: [
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _gunler[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: renk.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            for (var s = 0; s < satir; s++) ...[
              Divider(height: 1, color: renk.outlineVariant.withValues(alpha: 0.7)),
              Row(children: [
                for (var c = 0; c < 7; c++)
                  SizedBox(
                    width: hucreGenislik,
                    height: hucreYukseklik,
                    child: _hucre(
                      context,
                      DateTime(ay.year, ay.month, s * 7 + c - bosluk + 1),
                      bugun,
                      renk,
                      hucreYukseklik,
                    ),
                  ),
              ]),
            ],
            if (lejant) ...[
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 18,
                runSpacing: 6,
                children: [
                  _lejantOgesi('Çalışıldı', Renkler.yesil, renk),
                  _lejantOgesi('Hafta tatili', Renkler.gri, renk),
                  _lejantOgesi('Eksik kayıt', Renkler.turuncu, renk),
                ],
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _lejantOgesi(String yazi, Color r, ColorScheme renk) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 6, backgroundColor: r),
          const SizedBox(width: 6),
          Text(yazi, style: TextStyle(fontSize: 13, color: renk.onSurface)),
        ],
      );

  Widget _hucre(
      BuildContext context, DateTime t, DateTime bugun, ColorScheme renk, double yukseklik) {
    final buAy = t.month == ay.month && t.year == ay.year;
    if (!buAy) {
      return Center(
        child: Text('${t.day}',
            style: TextStyle(fontSize: 16, color: renk.outline.withValues(alpha: 0.6))),
      );
    }

    final anahtar = Bicim.anahtar(t);
    final k = kayitlar[anahtar];
    final bugunMu = t == bugun;
    final gelecek = t.isAfter(bugun);
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

    // Nokta ve zemin
    Color? nokta;
    Color? zemin;
    if (kesildi && (k == null || k.durum == GunDurumu.haftaTatili)) {
      nokta = Renkler.kirmizi;
      zemin = Renkler.kirmizi.withValues(alpha: koyu ? 0.22 : 0.10);
    } else if (k != null) {
      nokta = takvimNoktaRengi(k.durum);
      zemin = k.durum == GunDurumu.geldi
          ? Renkler.yesil.withValues(alpha: koyu ? 0.16 : 0.07)
          : nokta.withValues(alpha: koyu ? 0.22 : 0.12);
    } else if (otomatikTatil) {
      nokta = Renkler.gri;
      zemin = Renkler.gri.withValues(alpha: koyu ? 0.2 : 0.12);
    } else if (!gelecek) {
      nokta = Renkler.turuncu; // eksik kayıt
      zemin = Renkler.turuncu.withValues(alpha: koyu ? 0.18 : 0.10);
    }

    final cap = (yukseklik - 6).clamp(36.0, 52.0).toDouble();
    Widget daire = Container(
      width: cap,
      height: cap,
      decoration: BoxDecoration(
        color: zemin,
        shape: BoxShape.circle,
        border: bugunMu ? Border.all(color: renk.primary, width: 2) : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${t.day}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: gelecek ? renk.outline : renk.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: nokta ?? Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (k != null && k.mesaiSaat > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('+${Bicim.sayi(k.mesaiSaat)}',
                    style: const TextStyle(
                        fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          if (not)
            const Positioned(
              left: 2,
              top: 2,
              child: CircleAvatar(radius: 3, backgroundColor: Color(0xFFF9A825)),
            ),
          if (inisiyatif)
            Positioned(
              left: -2,
              bottom: -2,
              child: Icon(Icons.volunteer_activism, size: 12, color: renk.tertiary),
            ),
        ],
      ),
    );

    if (uyusmazlik != null) {
      daire = CustomPaint(
        foregroundPainter: KesikliCerceve(
          renk: turuncu,
          kalinlik: uyusmazlik == Uyusmazlik.farkli ? 2.2 : 1.6,
          yaricap: cap / 2,
        ),
        child: daire,
      );
    }

    return Semantics(
      button: true,
      label: '${t.day} ${Bicim.gunAdi(t)}${k == null ? '' : ', ${k.durum.etiket}'}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onGunSec(t),
        child: Center(child: daire),
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
