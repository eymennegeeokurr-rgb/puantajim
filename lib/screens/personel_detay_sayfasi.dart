import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/gun_kaydi.dart';
import '../models/para_hareketi.dart'; // HareketTuru etiket/isaret uzantıları
import '../models/veri_paketi.dart';
import '../services/bicim.dart';
import '../services/bulut.dart';
import '../services/hesaplama.dart';
import '../services/rapor_uretici.dart';
import '../widgets/ay_gezgini.dart';
import '../widgets/rapor_gonder.dart';

/// YÖNETİCİ: Bir elemanın puantajı (sadece görüntüleme).
class PersonelDetaySayfasi extends StatefulWidget {
  final String ad;
  final String uid;
  final VeriPaketi ilkVeri;
  final int ilkZaman;

  const PersonelDetaySayfasi({
    super.key,
    required this.ad,
    required this.uid,
    required this.ilkVeri,
    required this.ilkZaman,
  });

  @override
  State<PersonelDetaySayfasi> createState() => _PersonelDetaySayfasiState();
}

class _PersonelDetaySayfasiState extends State<PersonelDetaySayfasi> {
  late VeriPaketi _veri = widget.ilkVeri;
  late int _zaman = widget.ilkZaman;
  bool _yenileniyor = false;

  Future<void> _yenile() async {
    setState(() => _yenileniyor = true);
    try {
      final v = await Bulut.personelVerisi(widget.uid);
      if (v != null) {
        _veri = v.veri;
        _zaman = v.zaman;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Yenilenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _yenileniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final profil = _veri.profil;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ad),
            Text(
              'Son güncelleme: ${_zaman == 0 ? '-' : '${Bicim.kisaTarih(DateTime.fromMillisecondsSinceEpoch(_zaman))} '
                  '${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(_zaman)).format(context)}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          _yenileniyor
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  tooltip: 'Yenile', icon: const Icon(Icons.refresh), onPressed: _yenile),
        ],
      ),
      body: profil == null
          ? const Center(child: Text('Bu kişi henüz profil bilgilerini girmemiş.'))
          : ValueListenableBuilder<DateTime>(
              valueListenable: Depo.instance.seciliAy,
              builder: (context, ay, _) {
                final kayitlar = _veri.ayKayitlari(ay);
                final hareketler = _veri.ayHareketleri(ay);
                final notlar = _veri.ayNotlari(ay);
                final ozet = Hesaplama.hesapla(
                  profil: profil,
                  ay: ay,
                  kayitlar: kayitlar,
                  hareketler: hareketler,
                  oncekiAyKayitlari: _veri.ayKayitlari(DateTime(ay.year, ay.month - 1)),
                );
                final uretici = RaporUretici(
                  profil: profil,
                  ozet: ozet,
                  kayitlar: kayitlar,
                  hareketler: hareketler,
                  notlar: notlar,
                );

                return ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    const AyGezgini(),
                    Card(
                      color: renk.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: ListTile(
                        leading: const Icon(Icons.visibility),
                        title: const Text('Sadece görüntüleme'),
                        subtitle: Text(
                            '${profil.gorev.isEmpty ? '' : '${profil.gorev} • '}'
                            'Maaş ${Bicim.para(profil.ucret)}'),
                      ),
                    ),

                    // ---- Özet
                    Card(
                      color: renk.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Text(ozet.ayBitti ? 'Kalan alacak' : 'Şu ana kadarki alacak',
                              style: TextStyle(color: renk.onPrimaryContainer)),
                          Text(Bicim.para(ozet.net),
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: renk.onPrimaryContainer)),
                          Text(
                            ozet.bankaVar
                                ? 'Bankaya ${Bicim.para(ozet.bankayaYatan)}  •  Elden ${Bicim.para(ozet.elden)}'
                                    '${ozet.hacizOrani > 0 ? '\nHaciz (${ozet.hacizEtiketi}): ${Bicim.para(ozet.haciz)}' : ''}'
                                : 'Hepsi elden',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: renk.onPrimaryContainer),
                          ),
                        ]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: Row(children: [
                        Expanded(
                          child: FilledButton.icon(
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
                    if (ozet.isaretsizGun > 0)
                      Card(
                        color: renk.errorContainer,
                        child: ListTile(
                          leading: Icon(Icons.warning_amber, color: renk.onErrorContainer),
                          title: Text('${ozet.isaretsizGun} gün girilmemiş',
                              style: TextStyle(color: renk.onErrorContainer)),
                        ),
                      ),

                    // ---- Hesap
                    _bolum(context, 'Hakediş Hesabı', [
                      for (final s in uretici.hesapSatirlari) _satir(s.$1, s.$2),
                      const Divider(),
                      for (final s in uretici.odemeSatirlari) _satir(s.$1, s.$2),
                    ]),

                    // ---- Günler
                    _bolum(context, 'Günler (${kayitlar.length} kayıt)', [
                      if (kayitlar.isEmpty) const Text('Bu ay kayıt yok'),
                      for (final k in kayitlar) _gunSatiri(k, renk),
                    ]),

                    // ---- Avans / ödemeler
                    if (hareketler.isNotEmpty)
                      _bolum(context, 'Avans ve Ödemeler', [
                        for (final h in hareketler)
                          _satir(
                            '${Bicim.kisaTarih(Bicim.anahtarOku(h.tarih))}  ${h.tur.etiket}'
                                '${h.aciklama.isEmpty ? '' : ' - ${h.aciklama}'}',
                            '${h.tur.isaret > 0 ? '+' : '−'} ${Bicim.para(h.tutar)}',
                          ),
                      ]),

                    // ---- Notlar
                    if (notlar.isNotEmpty)
                      _bolum(context, 'Notlar (${notlar.length})', [
                        for (final n in notlar)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${Bicim.gunAy(Bicim.anahtarOku(n.tarih))}  ${n.saat}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: renk.primary),
                                ),
                                const SizedBox(height: 2),
                                Text(n.metin),
                              ],
                            ),
                          ),
                      ]),
                  ],
                );
              },
            ),
    );
  }

  Widget _bolum(BuildContext context, String baslik, List<Widget> icerik) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              ...icerik,
            ],
          ),
        ),
      );

  Widget _satir(String e, String d) {
    final vurgulu = RaporUretici.vurgulu(e);
    final stil = TextStyle(
      fontWeight: vurgulu ? FontWeight.w800 : FontWeight.normal,
      fontSize: vurgulu ? 14.5 : 13.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(e, style: stil)),
          const SizedBox(width: 8),
          Text(d, style: stil),
        ],
      ),
    );
  }

  Widget _gunSatiri(GunKaydi k, ColorScheme renk) {
    final t = Bicim.anahtarOku(k.tarih);
    final ek = <String>[
      if (k.giris != null || k.cikis != null) '${k.giris ?? '--:--'}-${k.cikis ?? '--:--'}',
      if (k.mesaiSaat > 0) '+${Bicim.sayi(k.mesaiSaat)} sa',
      if (k.durum == GunDurumu.raporlu) k.raporTuru.etiket,
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text('${t.day.toString().padLeft(2, '0')} ${Bicim.gunAdi(t)}',
                style: const TextStyle(fontSize: 13)),
          ),
          Icon(k.durum.ikon, size: 16, color: k.durum.renk),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.weekday == DateTime.sunday && k.durum == GunDurumu.geldi
                      ? 'Pazar çalıştı'
                      : k.durum.raporEtiketi,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (ek.isNotEmpty)
                  Text(ek, style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)),
                if (k.not != null && k.not!.isNotEmpty)
                  Text(k.not!, style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
