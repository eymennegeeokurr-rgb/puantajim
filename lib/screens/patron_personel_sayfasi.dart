import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../data/patron_depo.dart';
import '../models/gun_kaydi.dart';
import '../models/veri_paketi.dart';
import '../services/bicim.dart';
import '../services/bulut.dart';
import '../services/hesaplama.dart';
import '../services/puantaj_hesaplama_engine.dart';
import '../services/rapor_uretici.dart';
import '../widgets/akilli_takvim_widget.dart';
import '../widgets/ay_gezgini.dart';
import '../widgets/rapor_gonder.dart';
import 'gun_duzenle_sayfasi.dart';
import 'personel_detay_sayfasi.dart';

/// PATRON MODU: bir işçinin patron puantajı.
///
///  - Takvimdeki günler PATRONUN kaydıdır (okuma/yazma); hakediş bundan hesaplanır.
///  - İşçinin kendi kaydı salt okunur karşılaştırma olarak kullanılır; uyuşmayan
///    günler turuncu kesikli çerçeveyle gösterilir.
///  - Maaş, banka, haciz, yol gibi ayarlar ve avanslar işçinin kendi kaydından gelir.
class PatronPersonelSayfasi extends StatefulWidget {
  final String ad;
  final String uid;
  final ({VeriPaketi veri, int zaman})? ilkVeri;
  final ValueChanged<({VeriPaketi veri, int zaman})?>? veriYenilendi;

  const PatronPersonelSayfasi({
    super.key,
    required this.ad,
    required this.uid,
    required this.ilkVeri,
    this.veriYenilendi,
  });

  @override
  State<PatronPersonelSayfasi> createState() => _PatronPersonelSayfasiState();
}

class _PatronPersonelSayfasiState extends State<PatronPersonelSayfasi> {
  final _patron = PatronDepo.instance;
  late ({VeriPaketi veri, int zaman})? _isci = widget.ilkVeri;
  bool _yenileniyor = false;
  AylikOzet? _sonOzet;

  Future<void> _yenile() async {
    setState(() => _yenileniyor = true);
    try {
      final v = await Bulut.personelVerisi(widget.uid);
      _isci = v;
      widget.veriYenilendi?.call(v);
      await _patron.yenile(Depo.instance.seciliAy.value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Yenilenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _yenileniyor = false);
    }
  }

  Map<String, GunKaydi> _isciAyi(DateTime ay) =>
      {for (final k in _isci?.veri.ayKayitlari(ay) ?? const <GunKaydi>[]) k.tarih: k};

  Future<void> _gunAc(DateTime t, AylikOzet? ozet) async {
    final anahtar = Bicim.anahtar(t);
    await gunPaneliAc(
      context,
      tarih: t,
      mevcut: _patron.gun(widget.uid, t),
      isciKaydi: _isciAyi(DateTime(t.year, t.month))[anahtar],
      profil: _isci?.veri.profil,
      hafta: (ozet != null && ozet.ay.year == t.year && ozet.ay.month == t.month)
          ? ozet.haftalar[t.day]
          : null,
      patronModu: true,
      kimin: widget.ad,
      kaydet: (k) => _patron.gunKaydet(widget.uid, k),
      sil: () => _patron.gunSil(widget.uid, anahtar),
    );
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final seciliAy = Depo.instance.seciliAy;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ad, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Patron puantajı', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          if (_isci != null)
            IconButton(
              tooltip: 'İşçinin kendi puantajı',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PersonelDetaySayfasi(
                  ad: widget.ad,
                  uid: widget.uid,
                  ilkVeri: _isci!.veri,
                  ilkZaman: _isci!.zaman,
                ),
              )),
            ),
          _yenileniyor
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(tooltip: 'Yenile', icon: const Icon(Icons.refresh), onPressed: _yenile),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_patron, seciliAy]),
        builder: (context, _) {
          final ay = seciliAy.value;
          final profil = _isci?.veri.profil;
          final patronKayit = _patron.isciKayitlari(widget.uid, ay);
          final isciAy = _isciAyi(ay);
          final hareketler = _isci?.veri.ayHareketleri(ay) ?? const [];
          final ozet = profil == null
              ? null
              : Hesaplama.hesapla(
                  profil: profil,
                  ay: ay,
                  kayitlar: patronKayit,
                  hareketler: hareketler,
                  oncekiAyKayitlari:
                      _patron.isciKayitlari(widget.uid, DateTime(ay.year, ay.month - 1)),
                );
          final farklar = _farklar(ay, isciAy);
          _sonOzet = ozet;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const AyGezgini(),
              if (profil == null)
                Card(
                  color: renk.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.info_outline, color: renk.onErrorContainer),
                    title: Text('Maaş bilgisi yok',
                        style: TextStyle(color: renk.onErrorContainer)),
                    subtitle: Text(
                      'İşçi uygulamasında profilini doldurup veri gönderince hakediş hesaplanır. '
                      'Günleri şimdiden girebilirsiniz.',
                      style: TextStyle(color: renk.onErrorContainer),
                    ),
                  ),
                ),
              if (ozet != null) _ozetKarti(ozet, profil == null ? null : patronKayit, renk),
              AkilliTakvimWidget(
                ay: ay,
                kayitlar: {for (final k in patronKayit) k.tarih: k},
                karsilastirma: isciAy,
                ozet: ozet,
                onGunSec: (t) => _gunAc(t, ozet),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
                child: Text(
                  'Güne dokunup durum seçin. Turuncu kesikli çerçeve: işçinin kaydı sizinkinden farklı.',
                  style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                ),
              ),
              if (farklar.isNotEmpty) _farkKarti(farklar, isciAy, renk),
            ],
          );
        },
      ),
    );
  }

  /// Bugüne kadar uyuşmayan günler (tarih, uyuşmazlık)
  List<(DateTime, Uyusmazlik)> _farklar(DateTime ay, Map<String, GunKaydi> isciAy) {
    final patron = _patron.isciAyi(widget.uid, ay);
    final bugun = Bicim.sadeceGun(DateTime.now());
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    final l = <(DateTime, Uyusmazlik)>[];
    for (var g = 1; g <= gunSayisi; g++) {
      final t = DateTime(ay.year, ay.month, g);
      if (t.isAfter(bugun)) break;
      final a = Bicim.anahtar(t);
      final u = PuantajHesaplamaEngine.karsilastir(patron[a], isciAy[a]);
      if (u == Uyusmazlik.farkli || u == Uyusmazlik.patronGirmedi) l.add((t, u!));
    }
    return l;
  }

  Widget _ozetKarti(AylikOzet o, List<GunKaydi>? kayitlar, ColorScheme renk) {
    final uretici = RaporUretici(
      profil: _isci!.veri.profil!,
      ozet: o,
      kayitlar: kayitlar ?? const [],
      hareketler: _isci!.veri.ayHareketleri(o.ay),
      notlar: _isci!.veri.ayNotlari(o.ay),
    );
    return Column(children: [
      Card(
        color: renk.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(o.ayBitti ? 'Ödenecek (patron puantajı)' : 'Şu ana kadar (patron puantajı)',
                style: TextStyle(color: renk.onPrimaryContainer)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(Bicim.para(o.net),
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: renk.onPrimaryContainer)),
            ),
            Text(
              [
                '${Bicim.sayi(o.odenenGun)}/30 gün',
                if (o.mesaiSaat > 0) '${Bicim.sayi(o.mesaiSaat)} sa mesai',
                if (o.kesilenPazar > 0) '${o.kesilenPazar} pazar kesik',
                if (o.inisiyatifPazarGunleri.isNotEmpty)
                  '${o.inisiyatifPazarGunleri.length} pazar inisiyatif',
              ].join('  •  '),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: renk.onPrimaryContainer),
            ),
            if (o.bankaVar)
              Text(
                'Bankaya ${Bicim.para(o.bankayaYatan)}  •  Elden ${Bicim.para(o.elden)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: renk.onPrimaryContainer),
              ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => raporHazirlaVeGoster(context, uretici, pdf: true),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => raporHazirlaVeGoster(context, uretici, pdf: false),
              icon: const Icon(Icons.table_view),
              label: const Text('Excel'),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _farkKarti(
      List<(DateTime, Uyusmazlik)> farklar, Map<String, GunKaydi> isciAy, ColorScheme renk) {
    const turuncu = Color(0xFFEF6C00);
    final patronGirmedi = farklar
        .where((f) => f.$2 == Uyusmazlik.patronGirmedi)
        .map((f) => isciAy[Bicim.anahtar(f.$1)]!)
        .toList();

    String yazi(GunKaydi? k, DateTime t) {
      if (k == null) return 'girilmedi';
      final etiket =
          t.weekday == DateTime.sunday && k.durum == GunDurumu.geldi ? 'Pazar çalıştı' : k.durum.etiket;
      return k.mesaiSaat > 0 ? '$etiket +${Bicim.sayi(k.mesaiSaat)}' : etiket;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.compare_arrows, color: turuncu),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${farklar.length} gün uyuşmuyor',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ]),
            const SizedBox(height: 6),
            for (final f in farklar)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _gunAc(f.$1, _sonOzet),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    SizedBox(
                      width: 74,
                      child: Text('${f.$1.day.toString().padLeft(2, '0')} ${Bicim.gunAdi(f.$1)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Siz: '),
                          TextSpan(
                              text: yazi(_patron.gun(widget.uid, f.$1), f.$1),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          const TextSpan(text: '   İşçi: '),
                          TextSpan(
                              text: yazi(isciAy[Bicim.anahtar(f.$1)], f.$1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: turuncu)),
                        ]),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ]),
                ),
              ),
            if (patronGirmedi.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await _patron.isciKaydiniKabulEt(widget.uid, patronGirmedi);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${patronGirmedi.length} gün işçinin kaydından alındı')));
                    }
                  },
                  icon: const Icon(Icons.done_all),
                  label: Text('Girmediğim ${patronGirmedi.length} günü işçiden al'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
