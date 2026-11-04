import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/gun_kaydi.dart';
import '../services/app_mode_controller.dart';
import '../services/bicim.dart';
import '../services/bulut.dart';
import '../services/hesaplama.dart';
import '../tema.dart';
import '../widgets/akilli_takvim_widget.dart';
import '../widgets/ay_gezgini.dart';
import '../widgets/hesabim_karti.dart';
import '../widgets/kurulum_ipucu.dart';
import '../widgets/mod_secici.dart';
import 'gun_duzenle_sayfasi.dart';

/// Puantaj sekmesi: özet ana sayfa  <->  takvim görünümü ("Puantajı Gör").
class PuantajSekmesi extends StatefulWidget {
  final VoidCallback hakedisAc;
  const PuantajSekmesi({super.key, required this.hakedisAc});

  @override
  State<PuantajSekmesi> createState() => _PuantajSekmesiState();
}

class _PuantajSekmesiState extends State<PuantajSekmesi> {
  bool _takvim = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_takvim,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _takvim = false);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _takvim
            ? _TakvimGorunumu(
                key: const ValueKey('takvim'),
                geri: () => setState(() => _takvim = false),
              )
            : _OzetGorunumu(
                key: const ValueKey('ozet'),
                takvimAc: () => setState(() => _takvim = true),
                hakedisAc: widget.hakedisAc,
              ),
      ),
    );
  }
}

/// Bir ayın hesabı (avanslar dahil)
AylikOzet? _ayOzeti(DateTime ay, {bool hareketli = true}) {
  final depo = Depo.instance;
  final p = depo.profil;
  if (p == null) return null;
  return Hesaplama.hesapla(
    profil: p,
    ay: ay,
    kayitlar: depo.ayKayitlari(ay),
    hareketler: hareketli ? depo.ayHareketleri(ay) : const [],
    oncekiAyKayitlari: depo.ayKayitlari(DateTime(ay.year, ay.month - 1)),
  );
}

/// Durumun kısa yazısı (etiket çipleri için)
String durumYazisi(GunDurumu d, DateTime t) {
  if (d == GunDurumu.geldi) {
    return t.weekday == DateTime.sunday ? 'Pazar çalıştı' : 'Çalışıldı';
  }
  if (d == GunDurumu.haftaTatili) return 'Hafta tatili';
  return d.raporEtiketi;
}

// =============================================================================
// ÖZET (ana sayfa)
// =============================================================================

class _OzetGorunumu extends StatefulWidget {
  final VoidCallback takvimAc;
  final VoidCallback hakedisAc;
  const _OzetGorunumu({super.key, required this.takvimAc, required this.hakedisAc});

  @override
  State<_OzetGorunumu> createState() => _OzetGorunumuState();
}

class _OzetGorunumuState extends State<_OzetGorunumu> {
  late final Stream<List<Istek>> _istekler = Bulut.gelenIstekler();

  void _bildirimler(List<Istek> bekleyen) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: bekleyen.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Yeni bildirim yok', textAlign: TextAlign.center),
                )
              : const Column(mainAxisSize: MainAxisSize.min, children: [OnayBandi()]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(children: [
          Icon(Icons.bar_chart_rounded, size: 28),
          SizedBox(width: 8),
          Text('Puantaj'),
        ]),
        actions: [
          ListenableBuilder(
            listenable: AppModeController.instance.dinleyici,
            builder: (context, _) => AppModeController.instance.patronAcildi &&
                    AppModeController.instance.patronKullanilabilir
                ? IconButton(
                    tooltip: 'Patron moduna geç',
                    icon: const Icon(Icons.groups_outlined),
                    onPressed: () => patronOl(context),
                  )
                : const SizedBox.shrink(),
          ),
          StreamBuilder<List<Istek>>(
            stream: _istekler,
            builder: (context, snap) {
              final bekleyen =
                  (snap.data ?? const <Istek>[]).where((i) => i.bekliyor).toList();
              return IconButton(
                tooltip: 'Bildirimler',
                onPressed: () => _bildirimler(bekleyen),
                icon: Badge(
                  isLabelVisible: bekleyen.isNotEmpty,
                  smallSize: 9,
                  backgroundColor: Renkler.kirmizi,
                  child: const Icon(Icons.notifications_none_rounded, size: 28),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([depo, depo.seciliAy]),
        builder: (context, _) {
          final ay = depo.seciliAy.value;
          final o = _ayOzeti(ay);
          final ad = (depo.profil?.adSoyad ?? '').trim().split(RegExp(r'\s+')).first;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const KurulumIpucu(),
              // ---- Selamlama
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ad.isEmpty ? 'Merhaba' : 'Merhaba, $ad',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Günlük çalışmalarınız hayırlı olsun.',
                            style: TextStyle(fontSize: 14, color: renk.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.engineering, size: 72, color: renk.primary.withValues(alpha: 0.18)),
                ]),
              ),
              const AyGezgini(),
              if (o != null) _HakedisKarti(ozet: o, onTap: widget.hakedisAc),
              if (o != null) _DevamlilikKarti(ozet: o, onTap: widget.takvimAc),
              if (o != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Expanded(
                      child: _MiniKart(
                        ikon: Icons.calendar_month_outlined,
                        baslik: 'Hafta tatili',
                        deger: '${o.adet(GunDurumu.haftaTatili) + o.otomatikTatil}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniKart(
                        ikon: Icons.schedule,
                        baslik: 'Mesai',
                        deger: '${Bicim.sayi(o.mesaiSaat)} saat',
                      ),
                    ),
                  ]),
                ),
              if (Bulut.oturum.value != null) const OnayBandi(),
              const _SonAktiviteler(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: FilledButton.icon(
                  onPressed: widget.takvimAc,
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('Puantajı Gör', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Renkler.lacivert,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lacivert "Tahmini hakediş" kartı
class _HakedisKarti extends StatelessWidget {
  final AylikOzet ozet;
  final VoidCallback onTap;
  const _HakedisKarti({required this.ozet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = ozet;
    const beyaz = Colors.white;
    final soluk = Colors.white.withValues(alpha: 0.75);
    Widget alt(IconData ikon, String baslik, String deger) => Expanded(
          child: Row(children: [
            Icon(ikon, color: beyaz, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik, style: TextStyle(color: soluk, fontSize: 13)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(deger,
                        style: const TextStyle(
                            color: beyaz, fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ]),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: Renkler.lacivert,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(children: [
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: beyaz, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.ayBitti ? 'Hakediş' : 'Tahmini hakediş',
                          style: TextStyle(color: soluk, fontSize: 15)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(Bicim.para(o.net),
                            style: const TextStyle(
                                color: beyaz, fontSize: 32, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.trending_up_rounded, color: Renkler.yesil, size: 30),
              ]),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withValues(alpha: 0.15)),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(children: [
                  if (o.bankaVar)
                    alt(Icons.account_balance, 'Banka', Bicim.para(o.bankayaYatan))
                  else
                    alt(Icons.payments_outlined, 'Avans', Bicim.para(o.avans)),
                  VerticalDivider(color: Colors.white.withValues(alpha: 0.15), width: 24),
                  alt(Icons.money, 'Elden', Bicim.para(o.elden)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "Aylık Devamlılık" halka kartı
class _DevamlilikKarti extends StatelessWidget {
  final AylikOzet ozet;
  final VoidCallback onTap;
  const _DevamlilikKarti({required this.ozet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final o = ozet;
    final oran = (o.odenenGun / 30).clamp(0.0, 1.0).toDouble();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _Halka(oran: oran, zemin: renk.outlineVariant, dolu: Renkler.yesil),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    FittedBox(
                      child: Text('${Bicim.sayi(o.odenenGun)} / 30',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    Text('gün', style: TextStyle(fontSize: 13, color: renk.onSurfaceVariant)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aylık Devamlılık',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Bu ay ${Bicim.sayi(o.calisilanGun)} gün çalıştınız.'
                    '${o.isaretsizGun > 0 ? '\n${o.isaretsizGun} gün girilmedi.' : ''}',
                    style: TextStyle(fontSize: 13.5, color: renk.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

class _Halka extends CustomPainter {
  final double oran;
  final Color zemin;
  final Color dolu;
  const _Halka({required this.oran, required this.zemin, required this.dolu});

  @override
  void paint(Canvas canvas, Size size) {
    const kalinlik = 9.0;
    final merkez = size.center(Offset.zero);
    final yaricap = math.min(size.width, size.height) / 2 - kalinlik / 2;
    final boya = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalinlik
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(merkez, yaricap, boya..color = zemin);
    if (oran > 0) {
      canvas.drawArc(Rect.fromCircle(center: merkez, radius: yaricap), -math.pi / 2,
          2 * math.pi * oran, false, boya..color = dolu);
    }
  }

  @override
  bool shouldRepaint(_Halka e) => e.oran != oran || e.zemin != zemin || e.dolu != dolu;
}

class _MiniKart extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String deger;
  const _MiniKart({required this.ikon, required this.baslik, required this.deger});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renk.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: renk.outlineVariant),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: renk.surfaceContainerHigh,
          child: Icon(ikon, color: renk.onSurface, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: renk.onSurfaceVariant)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(deger,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Son 3 gün: Bugün, Dün, önceki gün — dokununca gün paneli açılır
class _SonAktiviteler extends StatelessWidget {
  const _SonAktiviteler();

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    final renk = Theme.of(context).colorScheme;
    final bugun = Bicim.sadeceGun(DateTime.now());
    final gunler = [for (var i = 0; i < 3; i++) DateTime(bugun.year, bugun.month, bugun.day - i)];

    String etiket(int i, DateTime t) =>
        i == 0 ? 'Bugün' : i == 1 ? 'Dün' : Bicim.gunAy(t).split(' ').take(2).join(' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 6),
            child: Row(children: [
              Icon(Icons.show_chart_rounded, size: 22),
              SizedBox(width: 8),
              Text('Son Aktiviteler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
          ),
          for (var i = 0; i < gunler.length; i++) ...[
            Divider(color: renk.outlineVariant),
            () {
              final t = gunler[i];
              final k = depo.gun(t);
              final Color r = k == null ? Renkler.turuncu : takvimNoktaRengi(k.durum);
              final yazi = k == null ? 'Girilmedi' : durumYazisi(k.durum, t);
              return InkWell(
                onTap: () => gunDuzenle(context, t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                  child: Row(children: [
                    CircleAvatar(radius: 6, backgroundColor: r),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(etiket(i, t),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        k != null && k.mesaiSaat > 0
                            ? '$yazi +${Bicim.sayi(k.mesaiSaat)}'
                            : yazi,
                        style: TextStyle(fontSize: 13, color: renk.onSurface),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              );
            }(),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// TAKVİM GÖRÜNÜMÜ ("Puantajı Gör")
// =============================================================================

class _TakvimGorunumu extends StatelessWidget {
  final VoidCallback geri;
  const _TakvimGorunumu({super.key, required this.geri});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        automaticallyImplyLeading: false,
        title: const Text('Puantaj'),
        actions: [
          IconButton(
            tooltip: 'Bu aya git',
            icon: const Icon(Icons.calendar_month_outlined, size: 28),
            onPressed: () {
              final s = DateTime.now();
              depo.seciliAy.value = DateTime(s.year, s.month);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Bugünü gir',
        onPressed: () => gunDuzenle(context, Bicim.sadeceGun(DateTime.now())),
        child: const Icon(Icons.add, size: 30),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([depo, depo.seciliAy]),
        builder: (context, _) {
          final ay = depo.seciliAy.value;
          final o = _ayOzeti(ay, hareketli: false);
          final kayitlar = depo.ayKayitlari(ay);
          final calisilan = o?.calisilanGun ?? 0;
          final tatil = (o?.adet(GunDurumu.haftaTatili) ?? 0) + (o?.otomatikTatil ?? 0);
          final eksik = o?.isaretsizGun ?? 0;
          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              const AyGezgini(),
              AkilliTakvimWidget(
                ay: ay,
                kayitlar: {for (final k in kayitlar) k.tarih: k},
                ozet: o,
                notVar: depo.notVar,
                onGunSec: (t) => gunDuzenle(context, t),
              ),
              const SizedBox(height: 6),
              _GunOzeti(calisilan: calisilan, tatil: tatil, eksik: eksik, ozet: o),
            ],
          );
        },
      ),
    );
  }
}

class _GunOzeti extends StatelessWidget {
  final double calisilan;
  final int tatil;
  final int eksik;
  final AylikOzet? ozet;
  const _GunOzeti(
      {required this.calisilan, required this.tatil, required this.eksik, required this.ozet});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final o = ozet;
    Widget sutun(Widget ikon, String baslik, String deger) => Expanded(
          child: Column(children: [
            ikon,
            const SizedBox(height: 6),
            Text(baslik,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: renk.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(deger, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ]),
        );
    Widget daireIkon(IconData i, Color r) => CircleAvatar(
          radius: 14,
          backgroundColor: r.withValues(alpha: 0.15),
          child: Icon(i, size: 18, color: r),
        );

    final ekler = <String>[
      if (o != null && o.adet(GunDurumu.gelmedi) > 0) 'Gelmedi ${o.adet(GunDurumu.gelmedi)}',
      if (o != null && o.adet(GunDurumu.ucretliIzin) + o.adet(GunDurumu.ucretsizIzin) > 0)
        'İzin ${o.adet(GunDurumu.ucretliIzin) + o.adet(GunDurumu.ucretsizIzin)}',
      if (o != null && o.raporGunu > 0) 'Rapor ${o.raporGunu}',
      if (o != null && o.mesaiSaat > 0) 'Mesai ${Bicim.sayi(o.mesaiSaat)} sa',
      if (o != null && o.kesilenPazar > 0) 'Kesilen pazar ${o.kesilenPazar}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.calendar_month_outlined, size: 20),
              SizedBox(width: 8),
              Text('Gün Özeti', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(children: [
                sutun(daireIkon(Icons.check, Renkler.yesil), 'Çalışılan gün', Bicim.sayi(calisilan)),
                VerticalDivider(color: renk.outlineVariant),
                sutun(daireIkon(Icons.calendar_month, Renkler.gri), 'Hafta tatili', '$tatil'),
                VerticalDivider(color: renk.outlineVariant),
                sutun(daireIkon(Icons.priority_high, Renkler.turuncu), 'Eksik kayıt', '$eksik'),
              ]),
            ),
            if (ekler.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(ekler.join('  •  '),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
