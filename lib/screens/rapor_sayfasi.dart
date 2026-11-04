import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../services/bicim.dart';
import '../services/hesaplama.dart';
import '../services/rapor_uretici.dart';
import '../tema.dart';
import '../widgets/ay_gezgini.dart';
import '../widgets/rapor_gonder.dart';

/// "Hakedişim": aylık hakediş özeti + PDF/Excel paylaşma.
class RaporSayfasi extends StatelessWidget {
  /// Geri okuna basınca (Puantaj sekmesine dön)
  final VoidCallback? geri;
  const RaporSayfasi({super.key, this.geri});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([depo, depo.seciliAy]),
      builder: (context, _) {
        final profil = depo.profil;
        if (profil == null) return const Scaffold();
        final ay = depo.seciliAy.value;
        final kayitlar = depo.ayKayitlari(ay);
        final hareketler = depo.ayHareketleri(ay);
        final o = Hesaplama.hesapla(
          profil: profil,
          ay: ay,
          kayitlar: kayitlar,
          hareketler: hareketler,
          oncekiAyKayitlari: depo.ayKayitlari(DateTime(ay.year, ay.month - 1)),
        );
        final uretici = RaporUretici(
          profil: profil,
          ozet: o,
          kayitlar: kayitlar,
          hareketler: hareketler,
          notlar: depo.ayNotlari(ay),
        );
        return Scaffold(
          appBar: AppBar(
            leading: geri == null
                ? null
                : IconButton(
                    tooltip: 'Geri',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: geri,
                  ),
            title: const Text('Hakedişim'),
            actions: [
              PopupMenuButton<bool>(
                tooltip: 'Paylaş',
                icon: const Icon(Icons.ios_share, size: 26),
                onSelected: (pdf) => raporHazirlaVeGoster(context, uretici, pdf: pdf),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: true,
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('PDF olarak paylaş'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: false,
                    child: ListTile(
                      leading: Icon(Icons.table_view_outlined),
                      title: Text('Excel olarak paylaş'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const AyGezgini(),
              _UstKart(ozet: o),
              if (o.isaretsizGun > 0) _uyari(context, o),
              _SatirKarti(satirlar: [
                (Icons.calendar_month_outlined, 'Günlük ücret', Bicim.para(o.gunlukUcret)),
                (Icons.check_circle_outline, 'Ödenen gün', '${Bicim.sayi(o.odenenGun)} / 30'),
                (Icons.schedule, 'Mesai ücreti', Bicim.para(o.mesaiUcreti)),
                if (o.pazarCalisilanGun > 0)
                  (Icons.wb_sunny_outlined, 'Pazar çalışması', Bicim.para(o.pazarCalismaUcreti)),
                if (o.yolVar) (Icons.directions_bus_outlined, 'Yol parası', Bicim.para(o.yolParasi)),
                if (o.ekOdeme > 0) (Icons.add_circle_outline, 'Ek ödeme / prim', Bicim.para(o.ekOdeme)),
                (
                  Icons.remove_circle_outline,
                  'Kesintiler',
                  _kesinti(o) > 0 ? '− ${Bicim.para(_kesinti(o))}' : Bicim.para(0)
                ),
              ]),
              _ToplamKart(tutar: o.net, ayBitti: o.ayBitti),
              if (o.bankaVar)
                _SatirKarti(baslik: 'Ödeme Dağılımı', satirlar: [
                  (Icons.account_balance_outlined, 'Bankaya yatacak', Bicim.para(o.bankayaYatan)),
                  if (o.hacizOrani > 0)
                    (Icons.gavel_outlined, 'Haciz (${o.hacizEtiketi})', Bicim.para(o.haciz)),
                  (Icons.money, 'Elden ödenecek', Bicim.para(o.elden)),
                ]),
              _DetayKarti(uretici: uretici, ozet: o),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: OutlinedButton.icon(
                  onPressed: () => raporHazirlaVeGoster(context, uretici, pdf: true),
                  icon: const Icon(Icons.share),
                  label: const Text('PDF olarak paylaş',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Avans + diğer kesintiler + (rapor tam ödeniyorsa) SGK'nın ödediği kısım
  static double _kesinti(AylikOzet o) => o.avans + o.kesinti + o.sgkDusulen;

  Widget _uyari(BuildContext context, AylikOzet o) {
    final renk = Theme.of(context).colorScheme;
    return Card(
      color: Renkler.turuncu.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Renkler.turuncu),
        title: Text('${o.isaretsizGun} gün için kayıt girilmemiş'),
        subtitle: Text('Girilmemiş günler ücrete sayılmaz.',
            style: TextStyle(color: renk.onSurfaceVariant)),
      ),
    );
  }
}

class _UstKart extends StatelessWidget {
  final AylikOzet ozet;
  const _UstKart({required this.ozet});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: Renkler.lacivert,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ozet.ayBitti ? 'Hakedişiniz' : 'Tahmini Hakedişiniz',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Bicim.para(ozet.net),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        const Icon(Icons.bar_chart_rounded, color: Renkler.yesil, size: 34),
      ]),
    );
  }
}

class _SatirKarti extends StatelessWidget {
  final String? baslik;
  final List<(IconData, String, String)> satirlar;
  const _SatirKarti({required this.satirlar, this.baslik});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (baslik != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4, left: 2),
                child: Text(baslik!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            for (var i = 0; i < satirlar.length; i++) ...[
              if (i > 0) Divider(color: renk.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: renk.surfaceContainerHigh,
                    child: Icon(satirlar[i].$1, size: 20, color: renk.onSurface),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(satirlar[i].$2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  Text(satirlar[i].$3,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToplamKart extends StatelessWidget {
  final double tutar;
  final bool ayBitti;
  const _ToplamKart({required this.tutar, required this.ayBitti});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: renk.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ayBitti ? 'TOPLAM HAKEDİŞ' : 'TOPLAM HAKEDİŞ (ŞU ANA KADAR)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: renk.onSecondaryContainer)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Bicim.para(tutar),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: renk.onSecondaryContainer)),
              ),
            ],
          ),
        ),
        const CircleAvatar(
          radius: 20,
          backgroundColor: Renkler.lacivert,
          child: Icon(Icons.check, color: Colors.white),
        ),
      ]),
    );
  }
}

/// Ayrıntılı hesap dökümü (açılır)
class _DetayKarti extends StatelessWidget {
  final RaporUretici uretici;
  final AylikOzet ozet;
  const _DetayKarti({required this.uretici, required this.ozet});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    Widget satir((String, String) s) {
      final vurgulu = RaporUretici.vurgulu(s.$1);
      final stil = TextStyle(
        fontWeight: vurgulu ? FontWeight.w800 : FontWeight.normal,
        fontSize: vurgulu ? 14.5 : 13.5,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(s.$1, style: stil)),
          const SizedBox(width: 8),
          Text(s.$2, style: stil),
        ]),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Ayrıntılı hesap', style: TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            for (final s in uretici.hesapSatirlari) satir(s),
            if (ozet.raporGunu > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  ozet.raporTamOdenir
                      ? 'Raporlu ${ozet.raporGunu} günün maaşı tam sayıldı. SGK rapor parasını kendisi '
                          'yatırır; işveren sadece aradaki farkı öder (tahmini).'
                      : 'Raporlu ${ozet.raporGunu} gün maaştan düşüldü; o günler için sadece SGK öder (tahmini).',
                  style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
