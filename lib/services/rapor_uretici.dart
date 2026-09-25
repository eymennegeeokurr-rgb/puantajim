import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/gun_kaydi.dart';
import '../models/not_kaydi.dart';
import '../models/para_hareketi.dart';
import '../models/profil.dart';
import 'bicim.dart';
import 'hesaplama.dart';

/// Aylık puantaj raporunu PDF ve Excel olarak üretir (bayt dizisi döner).
/// Dosya sistemi kullanmaz; bu sayede hem Android'de hem web'de çalışır.
class RaporUretici {
  final Profil profil;
  final AylikOzet ozet;
  final List<GunKaydi> kayitlar;
  final List<ParaHareketi> hareketler;
  final List<NotKaydi> notlar;

  RaporUretici({
    required this.profil,
    required this.ozet,
    required this.kayitlar,
    required this.hareketler,
    this.notlar = const [],
  });

  String get _ayKodu =>
      '${ozet.ay.year}-${ozet.ay.month.toString().padLeft(2, '0')}';

  String dosyaAdi(String uzanti) =>
      'Puantaj_${Bicim.dosyaAdi(profil.adSoyad)}_$_ayKodu.$uzanti';

  String get paylasimMetni =>
      '${profil.adSoyad} - ${Bicim.ay(ozet.ay)} puantaj ve hakediş';

  /// Ayın her günü için satır (kayıt yoksa boş)
  List<({DateTime tarih, GunKaydi? kayit})> get _gunler {
    final harita = {for (final k in kayitlar) k.tarih: k};
    return [
      for (var g = 1; g <= ozet.gunSayisi; g++)
        (
          tarih: DateTime(ozet.ay.year, ozet.ay.month, g),
          kayit: harita[Bicim.anahtar(DateTime(ozet.ay.year, ozet.ay.month, g))],
        ),
    ];
  }

  /// Hesap dökümü satırları (PDF ve Excel ortak)
  /// Tamamı büyük harf olan satırlar (TOPLAM, KALAN, ELDEN...) vurgulu gösterilir
  static bool vurgulu(String etiket) =>
      etiket.isNotEmpty && etiket == etiket.toUpperCase();

  /// Hesap dökümü satırları (PDF, Excel ve ekran ortak)
  List<(String, String)> get hesapSatirlari {
    final o = ozet;
    final aylik = o.ucretTipi == UcretTipi.aylik;
    return [
      if (aylik) ...[
        ('Aylık maaş (30 gün)', Bicim.para(o.ucret)),
        ('Günlük ücret (maaş ÷ 30)', Bicim.para(o.gunlukUcret)),
        ('Ücret ödenen gün', '${Bicim.sayi(o.odenenGun)} / 30'),
        if (o.kesintiGunu > 0)
          (
            'Eksik gün kesintisi (${Bicim.sayi(o.kesintiGunu)} gün)',
            '− ${Bicim.para(o.devamsizlikTutari)}'
          ),
      ] else ...[
        ('Günlük yevmiye', Bicim.para(o.gunlukUcret)),
        ('Ücret ödenen gün', Bicim.sayi(o.odenenGun)),
      ],
      ('Gün ücreti toplamı', Bicim.para(o.temelUcret)),
      if (o.mesaiSaat > 0)
        (
          'Fazla mesai (${Bicim.sayi(o.mesaiSaat)} sa × ${Bicim.para(o.saatlikUcret)} × ${Bicim.sayi(o.mesaiKatsayisi)})',
          '+ ${Bicim.para(o.mesaiUcreti)}'
        ),
      if (o.ekOdeme > 0) ('Ek ödeme / prim', '+ ${Bicim.para(o.ekOdeme)}'),
      ('TOPLAM HAKEDİŞ', Bicim.para(o.brut)),
      if (o.raporGunu > 0 && o.raporTamOdenir)
        (
          'SGK rapor parası (${Bicim.sayi(o.sgkOdenekGunu)} gün, SGK öder, tahmini)',
          '− ${Bicim.para(o.sgkOdenegi)}'
        ),
      if (o.avans > 0) ('Alınan avans', '− ${Bicim.para(o.avans)}'),
      if (o.kesinti > 0) ('Diğer kesintiler', '− ${Bicim.para(o.kesinti)}'),
      ('KALAN ALACAK', Bicim.para(o.net)),
    ];
  }

  /// Kalan alacağın banka / elden dağılımı (banka ayarı varsa)
  List<(String, String)> get odemeSatirlari {
    final o = ozet;
    if (!o.bankaVar) {
      return [('ELDEN ÖDENECEK', Bicim.para(o.net))];
    }
    final kaynak = o.bankaTipi == BankaTipi.asgari
        ? '${o.asgariYili} net asgari ücret'
        : 'anlaşılan tutar';
    return [
      ('Bankaya yatan (30 gün, $kaynak)', Bicim.para(o.bankaAylik)),
      ('Bankaya yatacak gün (SGK prim günü)', '${Bicim.sayi(o.primGunu)} / 30'),
      ('Bankaya yatacak tutar', Bicim.para(o.bankaHakedis)),
      if (o.hacizOrani > 0)
        ('Haciz kesintisi (${o.hacizEtiketi}, icraya gider)', '− ${Bicim.para(o.haciz)}'),
      ('BANKAYA NET YATACAK', Bicim.para(o.bankayaYatan)),
      ('ELDEN ÖDENECEK', Bicim.para(o.elden)),
      if (o.raporGunu > 0)
        (
          'SGK rapor parası (ayrıca SGK yatırır, tahmini)',
          Bicim.para(o.sgkOdenegi)
        ),
    ];
  }

  // ===========================================================================
  // PDF
  // ===========================================================================

  Future<Uint8List> pdf() async {
    final normal =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final kalin =
        pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: normal, bold: kalin),
      title: paylasimMetni,
      author: profil.adSoyad,
    );

    const k8 = pw.TextStyle(fontSize: 8);
    final baslikStil =
        pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Puantajım ile oluşturuldu • ${Bicim.kisaTarih(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.Text('Sayfa ${ctx.pageNumber}/${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
        build: (ctx) => [
          // ---- Başlık
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('AYLIK PUANTAJ VE HAKEDİŞ',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.Text(Bicim.ay(ozet.ay).toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(70),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(70),
              3: pw.FlexColumnWidth(),
            },
            children: [
              _bilgiSatiri('Adı Soyadı', profil.adSoyad, 'Görevi',
                  profil.gorev.isEmpty ? '-' : profil.gorev),
              _bilgiSatiri(
                  'Firma / Şantiye',
                  profil.firma.isEmpty ? '-' : profil.firma,
                  'Ücret',
                  '${profil.ucretTipi.etiket}: ${Bicim.para(profil.ucret)}'),
              _bilgiSatiri(
                  'Dönem',
                  '${Bicim.kisaTarih(ozet.ay)} - ${Bicim.kisaTarih(DateTime(ozet.ay.year, ozet.ay.month, ozet.gunSayisi))}',
                  'Normal Mesai',
                  'Günde ${Bicim.sayi(profil.gunlukSaat)} saat'),
            ],
          ),
          pw.SizedBox(height: 10),

          // ---- Günlük çizelge
          pw.TableHelper.fromTextArray(
            headers: const ['Tarih', 'Gün', 'Durum', 'Giriş', 'Çıkış', 'Mesai', 'Not'],
            data: _gunler.map((g) {
              final k = g.kayit;
              return [
                Bicim.kisaTarih(g.tarih),
                Bicim.gunAdi(g.tarih),
                k?.durum.raporEtiketi ?? '-',
                k?.giris ?? '',
                k?.cikis ?? '',
                (k?.mesaiSaat ?? 0) > 0 ? '${Bicim.sayi(k!.mesaiSaat)} sa' : '',
                k?.not ?? '',
              ];
            }).toList(),
            headerStyle: baslikStil,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: k8,
            cellHeight: 13,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            columnWidths: const {
              0: pw.FixedColumnWidth(58),
              1: pw.FixedColumnWidth(30),
              2: pw.FixedColumnWidth(68),
              3: pw.FixedColumnWidth(34),
              4: pw.FixedColumnWidth(34),
              5: pw.FixedColumnWidth(38),
              6: pw.FlexColumnWidth(),
            },
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
          pw.SizedBox(height: 12),

          // ---- Özet + Hesap yan yana
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 2, child: _durumOzeti()),
              pw.SizedBox(width: 12),
              pw.Expanded(flex: 3, child: _hesapTablosu()),
            ],
          ),

          // ---- Avans / kesinti / ek ödeme listesi
          if (hareketler.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Avans, Kesinti ve Ek Ödemeler',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: const ['Tarih', 'Tür', 'Açıklama', 'Tutar'],
              data: hareketler
                  .map((h) => [
                        Bicim.kisaTarih(Bicim.anahtarOku(h.tarih)),
                        h.tur.etiket,
                        h.aciklama,
                        '${h.tur.isaret > 0 ? '+' : '−'} ${Bicim.para(h.tutar)}',
                      ])
                  .toList(),
              headerStyle: baslikStil,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              cellStyle: k8,
              cellAlignments: {3: pw.Alignment.centerRight},
              columnWidths: const {
                0: pw.FixedColumnWidth(60),
                1: pw.FixedColumnWidth(80),
                2: pw.FlexColumnWidth(),
                3: pw.FixedColumnWidth(80),
              },
            ),
          ],

          // ---- Not defteri
          if (notlar.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Notlar',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: const ['Tarih', 'Not'],
              data: notlar
                  .map((n) => [
                        Bicim.kisaTarih(Bicim.anahtarOku(n.tarih)),
                        n.metin.trim(),
                      ])
                  .toList(),
              headerStyle: baslikStil,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
              cellStyle: k8,
              cellAlignment: pw.Alignment.topLeft,
              columnWidths: const {
                0: pw.FixedColumnWidth(60),
                1: pw.FlexColumnWidth(),
              },
            ),
          ],

          if (ozet.isaretsizGun > 0) ...[
            pw.SizedBox(height: 8),
            pw.Text(
                'Not: ${ozet.isaretsizGun} gün için kayıt girilmemiştir (tabloda "-").',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700)),
          ],

          // ---- İmza
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _imza('Çalışan', profil.adSoyad),
              _imza('Onaylayan', ''),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.TableRow _bilgiSatiri(String b1, String d1, String b2, String d2) {
    final bs = pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold);
    const ds = pw.TextStyle(fontSize: 8.5);
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(b1, style: bs)),
      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(d1, style: ds)),
      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(b2, style: bs)),
      pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(d2, style: ds)),
    ]);
  }

  pw.Widget _durumOzeti() {
    final satirlar = <List<String>>[
      for (final d in GunDurumu.values)
        if (ozet.adet(d) > 0) [d.raporEtiketi, '${ozet.adet(d)}'],
      ['Toplam mesai', '${Bicim.sayi(ozet.mesaiSaat)} saat'],
      if (ozet.isaretsizGun > 0) ['Girilmemiş gün', '${ozet.isaretsizGun}'],
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Gün Özeti',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          for (final s in satirlar)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Text(s[0], style: const pw.TextStyle(fontSize: 8.5))),
                pw.Text(s[1], style: const pw.TextStyle(fontSize: 8.5)),
              ]),
            ),
        ],
      ),
    );
  }

  pw.Widget _hesapTablosu() {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Hakediş Hesabı',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          for (final s in hesapSatirlari)
            _hesapSatiri(s.$1, s.$2, vurgulu: vurgulu(s.$1)),
          pw.SizedBox(height: 8),
          pw.Text('Ödeme Dağılımı',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          for (final s in odemeSatirlari)
            _hesapSatiri(s.$1, s.$2, vurgulu: vurgulu(s.$1)),
        ],
      ),
    );
  }

  pw.Widget _hesapSatiri(String e, String d, {bool vurgulu = false}) {
    final stil = pw.TextStyle(
      fontSize: vurgulu ? 9.5 : 8.5,
      fontWeight: vurgulu ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: vurgulu
          ? const pw.BoxDecoration(color: PdfColors.blueGrey50)
          : null,
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(e, style: stil)),
        pw.Text(d, style: stil),
      ]),
    );
  }

  pw.Widget _imza(String baslik, String ad) => pw.Column(children: [
        pw.Text(baslik, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 28),
        pw.Container(width: 150, height: 0.7, color: PdfColors.grey700),
        pw.SizedBox(height: 2),
        pw.Text(ad.isEmpty ? 'Ad Soyad / İmza' : ad,
            style: const pw.TextStyle(fontSize: 8)),
      ]);

  // ===========================================================================
  // EXCEL
  // ===========================================================================

  Uint8List excel() {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Puantaj');
    final kalin = CellStyle(bold: true);

    // ---- Sayfa 1: Günlük puantaj
    final p = excel['Puantaj'];
    p.appendRow([TextCellValue('AYLIK PUANTAJ - ${Bicim.ay(ozet.ay).toUpperCase()}')]);
    p.appendRow([TextCellValue('Adı Soyadı: ${profil.adSoyad}')]);
    p.appendRow([TextCellValue('Görevi: ${profil.gorev}')]);
    p.appendRow([TextCellValue('Firma / Şantiye: ${profil.firma}')]);
    p.appendRow([TextCellValue('')]);
    const basliklar = ['Tarih', 'Gün', 'Durum', 'Giriş', 'Çıkış', 'Mesai (saat)', 'Not'];
    p.appendRow(basliklar.map((b) => TextCellValue(b)).toList());
    _kalinYap(p, p.maxRows - 1, basliklar.length, kalin);
    for (var i = 0; i < 4; i++) {
      p.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).cellStyle = kalin;
    }

    for (final g in _gunler) {
      final k = g.kayit;
      p.appendRow([
        TextCellValue(Bicim.kisaTarih(g.tarih)),
        TextCellValue(Bicim.gunAdi(g.tarih)),
        TextCellValue(k?.durum.raporEtiketi ?? '-'),
        TextCellValue(k?.giris ?? ''),
        TextCellValue(k?.cikis ?? ''),
        (k?.mesaiSaat ?? 0) > 0 ? DoubleCellValue(k!.mesaiSaat) : TextCellValue(''),
        TextCellValue(k?.not ?? ''),
      ]);
    }
    p.appendRow([TextCellValue('')]);
    p.appendRow([
      TextCellValue('TOPLAM MESAİ'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(ozet.mesaiSaat),
    ]);
    _kalinYap(p, p.maxRows - 1, 6, kalin);
    p.setColumnWidth(0, 12);
    p.setColumnWidth(1, 6);
    p.setColumnWidth(2, 15);
    p.setColumnWidth(3, 8);
    p.setColumnWidth(4, 8);
    p.setColumnWidth(5, 12);
    p.setColumnWidth(6, 30);

    // ---- Sayfa 2: Hesap
    final h = excel['Hesap'];
    h.appendRow([TextCellValue('HAKEDİŞ HESABI - ${Bicim.ay(ozet.ay).toUpperCase()}')]);
    h.appendRow([TextCellValue(profil.adSoyad)]);
    h.appendRow([TextCellValue('')]);
    h.appendRow([TextCellValue('Gün Özeti')]);
    _kalinYap(h, h.maxRows - 1, 1, kalin);
    for (final d in GunDurumu.values) {
      if (ozet.adet(d) > 0) {
        h.appendRow([TextCellValue(d.raporEtiketi), IntCellValue(ozet.adet(d))]);
      }
    }
    h.appendRow([TextCellValue('Toplam mesai (saat)'), DoubleCellValue(ozet.mesaiSaat)]);
    if (ozet.isaretsizGun > 0) {
      h.appendRow([TextCellValue('Girilmemiş gün'), IntCellValue(ozet.isaretsizGun)]);
    }
    h.appendRow([TextCellValue('')]);
    h.appendRow([TextCellValue('Hakediş')]);
    _kalinYap(h, h.maxRows - 1, 1, kalin);
    for (final s in hesapSatirlari) {
      h.appendRow([TextCellValue(s.$1), TextCellValue(s.$2)]);
      if (vurgulu(s.$1)) _kalinYap(h, h.maxRows - 1, 2, kalin);
    }
    h.appendRow([TextCellValue('')]);
    h.appendRow([TextCellValue('Ödeme Dağılımı')]);
    _kalinYap(h, h.maxRows - 1, 1, kalin);
    for (final s in odemeSatirlari) {
      h.appendRow([TextCellValue(s.$1), TextCellValue(s.$2)]);
      if (vurgulu(s.$1)) _kalinYap(h, h.maxRows - 1, 2, kalin);
    }
    h.appendRow([TextCellValue('')]);
    h.appendRow([TextCellValue('Kalan alacak (sayı)'), DoubleCellValue(_yuvarla(ozet.net))]);
    if (ozet.bankaVar) {
      h.appendRow([TextCellValue('Bankaya net (sayı)'), DoubleCellValue(_yuvarla(ozet.bankayaYatan))]);
      if (ozet.hacizOrani > 0) {
        h.appendRow([TextCellValue('Haciz (sayı)'), DoubleCellValue(_yuvarla(ozet.haciz))]);
      }
    }
    h.appendRow([TextCellValue('Elden (sayı)'), DoubleCellValue(_yuvarla(ozet.elden))]);
    h.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = kalin;
    h.setColumnWidth(0, 55);
    h.setColumnWidth(1, 20);

    // ---- Sayfa 3: Avans ve ödemeler
    final a = excel['Avans ve Ödemeler'];
    a.appendRow(['Tarih', 'Tür', 'Açıklama', 'Tutar'].map((b) => TextCellValue(b)).toList());
    _kalinYap(a, 0, 4, kalin);
    for (final x in hareketler) {
      a.appendRow([
        TextCellValue(Bicim.kisaTarih(Bicim.anahtarOku(x.tarih))),
        TextCellValue(x.tur.etiket),
        TextCellValue(x.aciklama),
        DoubleCellValue(_yuvarla(x.tutar * x.tur.isaret)),
      ]);
    }
    a.setColumnWidth(0, 12);
    a.setColumnWidth(1, 16);
    a.setColumnWidth(2, 35);
    a.setColumnWidth(3, 14);

    // ---- Sayfa 4: Notlar
    if (notlar.isNotEmpty) {
      final n = excel['Notlar'];
      n.appendRow([TextCellValue('Tarih'), TextCellValue('Saat'), TextCellValue('Not')]);
      _kalinYap(n, 0, 3, kalin);
      for (final x in notlar) {
        n.appendRow([
          TextCellValue(Bicim.kisaTarih(Bicim.anahtarOku(x.tarih))),
          TextCellValue(x.saat),
          TextCellValue(x.metin.trim()),
        ]);
      }
      n.setColumnWidth(0, 12);
      n.setColumnWidth(1, 8);
      n.setColumnWidth(2, 80);
    }

    // encode(): web'de otomatik indirme yapmadan sadece baytları verir
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');
    return Uint8List.fromList(bytes);
  }

  void _kalinYap(Sheet s, int satir, int sutunSayisi, CellStyle stil) {
    for (var c = 0; c < sutunSayisi; c++) {
      s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: satir)).cellStyle = stil;
    }
  }

  double _yuvarla(double v) => (v * 100).roundToDouble() / 100;
}
