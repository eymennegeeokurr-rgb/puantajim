import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/gun_kaydi.dart';
import '../services/bicim.dart';
import '../services/hesaplama.dart';
import '../services/rapor_uretici.dart';
import '../widgets/ay_gezgini.dart';
import '../widgets/rapor_gonder.dart';

/// Aylık hakediş özeti + PDF/Excel gönderme.
class RaporSayfasi extends StatelessWidget {
  const RaporSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Hakedişim')),
      body: ListenableBuilder(
        listenable: Listenable.merge([depo, depo.seciliAy]),
        builder: (context, _) {
          final profil = depo.profil;
          if (profil == null) return const SizedBox.shrink();
          final ay = depo.seciliAy.value;
          final kayitlar = depo.ayKayitlari(ay);
          final hareketler = depo.ayHareketleri(ay);
          final ozet = Hesaplama.hesapla(
              profil: profil,
              ay: ay,
              kayitlar: kayitlar,
              hareketler: hareketler,
              oncekiAyKayitlari:
                  depo.ayKayitlari(DateTime(ay.year, ay.month - 1)));
          final uretici = RaporUretici(
              profil: profil,
              ozet: ozet,
              kayitlar: kayitlar,
              hareketler: hareketler,
              notlar: depo.ayNotlari(ay));
          final renk = Theme.of(context).colorScheme;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const AyGezgini(),

              // ---- Net alacak
              Card(
                color: renk.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    Text(ozet.ayBitti ? 'Kalan alacağım' : 'Şu ana kadarki alacağım',
                        style: TextStyle(color: renk.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(Bicim.para(ozet.net),
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: renk.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(
                      ozet.bankaVar
                          ? 'Bankaya ${Bicim.para(ozet.bankayaYatan)}  •  Elden ${Bicim.para(ozet.elden)}'
                          : 'Hepsi elden  •  Avans ${Bicim.para(ozet.avans)}',
                      style: TextStyle(
                          fontSize: 12.5, color: renk.onPrimaryContainer),
                    ),
                    if (ozet.bankaVar && ozet.hacizOrani > 0)
                      Text(
                        'Haciz (${ozet.hacizEtiketi}): ${Bicim.para(ozet.haciz)} icraya',
                        style: TextStyle(
                            fontSize: 12, color: renk.onPrimaryContainer),
                      ),
                  ]),
                ),
              ),

              // ---- Gönder butonları
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => raporHazirlaVeGoster(context, uretici, pdf: true),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF Gönder'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => raporHazirlaVeGoster(context, uretici, pdf: false),
                      icon: const Icon(Icons.table_view),
                      label: const Text('Excel Gönder'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                ]),
              ),

              if (ozet.isaretsizGun > 0)
                Card(
                  color: renk.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.warning_amber, color: renk.onErrorContainer),
                    title: Text(
                      '${ozet.isaretsizGun} gün için kayıt girilmemiş',
                      style: TextStyle(color: renk.onErrorContainer),
                    ),
                    subtitle: Text(
                      'Girilmemiş günler ücrete sayılmaz. Göndermeden önce Puantaj sekmesinden tamamlayın.',
                      style: TextStyle(color: renk.onErrorContainer),
                    ),
                  ),
                ),

              // ---- Gün özeti
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gün Özeti',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final d in GunDurumu.values)
                          if (ozet.adet(d) > 0)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(d.ikon, size: 16, color: d.renk),
                              label: Text('${d.raporEtiketi}: ${ozet.adet(d)}'),
                            ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.more_time,
                              size: 16, color: Color(0xFF6A1B9A)),
                          label: Text('Mesai: ${Bicim.sayi(ozet.mesaiSaat)} saat'),
                        ),
                        if (ozet.pazarCalisilanGun > 0)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(Icons.wb_sunny,
                                size: 16, color: GunDurumu.geldi.renk),
                            label: Text(
                                'Pazar çalıştı: ${Bicim.sayi(ozet.pazarCalisilanGun)}'),
                          ),
                        if (ozet.kesilenPazar > 0)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: Icon(Icons.block, size: 16, color: renk.error),
                            label: Text('Kesilen pazar: ${ozet.kesilenPazar}'),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),

              // ---- Hesap dökümü
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hakediş Hesabı',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      for (final s in uretici.hesapSatirlari)
                        _satir(context, s.$1, s.$2,
                            vurgulu: RaporUretici.vurgulu(s.$1)),
                    ],
                  ),
                ),
              ),

              // ---- Banka / elden dağılımı
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ödeme Dağılımı',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 8),
                      for (final s in uretici.odemeSatirlari)
                        _satir(context, s.$1, s.$2,
                            vurgulu: RaporUretici.vurgulu(s.$1)),
                      if (!ozet.bankaVar)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Bankaya yatan maaş varsa Profil > Banka ve Kesintiler bölümünden ayarlayın.',
                            style: TextStyle(
                                fontSize: 12, color: renk.onSurfaceVariant),
                          ),
                        ),
                      if (ozet.raporGunu > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            ozet.raporTamOdenir
                                ? 'Raporlu ${ozet.raporGunu} günün maaşı tam sayıldı. SGK rapor parasını '
                                    'kendisi yatırır; işveren sadece aradaki farkı öder. Rapor parası tahminidir, '
                                    'kesin tutar SGK hesabına göre değişebilir.'
                                : 'Raporlu ${ozet.raporGunu} gün maaştan düşüldü; o günler için sadece SGK öder (tahmini).',
                            style: TextStyle(
                                fontSize: 12, color: renk.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _satir(BuildContext context, String e, String d, {bool vurgulu = false}) {
    final renk = Theme.of(context).colorScheme;
    final stil = TextStyle(
      fontWeight: vurgulu ? FontWeight.w800 : FontWeight.normal,
      fontSize: vurgulu ? 15 : 13.5,
    );
    return Container(
      margin: EdgeInsets.only(top: vurgulu ? 6 : 0),
      padding: EdgeInsets.symmetric(horizontal: vurgulu ? 8 : 0, vertical: 5),
      decoration: vurgulu
          ? BoxDecoration(
              color: renk.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8))
          : null,
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
}
