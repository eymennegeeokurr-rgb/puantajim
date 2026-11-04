import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/gun_kaydi.dart';
import '../models/profil.dart';
import '../services/bicim.dart';
import '../services/hesaplama.dart';
import '../services/puantaj_hesaplama_engine.dart';
import 'notlar_sayfasi.dart';

/// BİREYSEL MOD: kendi günümü düzenlerim (Depo'ya yazar).
/// Pencereden "Bu güne not yaz" seçilirse not defteri o tarihle açılır.
Future<void> gunDuzenle(BuildContext context, DateTime tarih) async {
  final depo = Depo.instance;
  final profil = depo.profil;
  final ay = DateTime(tarih.year, tarih.month);
  HaftaSonucu? hafta;
  if (profil != null && tarih.weekday == DateTime.sunday) {
    hafta = Hesaplama.hesapla(
      profil: profil,
      ay: ay,
      kayitlar: depo.ayKayitlari(ay),
      hareketler: const [],
      oncekiAyKayitlari: depo.ayKayitlari(DateTime(ay.year, ay.month - 1)),
    ).haftalar[tarih.day];
  }
  final sonuc = await gunPaneliAc(
    context,
    tarih: tarih,
    mevcut: depo.gun(tarih),
    profil: profil,
    hafta: hafta,
    notDefteri: true,
    kaydet: depo.gunKaydet,
    sil: () => depo.gunSil(Bicim.anahtar(tarih)),
  );
  if (sonuc == 'not' && context.mounted) {
    await notDuzenle(context, tarih: tarih);
  }
}

/// Günün durumunu seçtiren alt panel (Bottom Sheet). Hem bireysel hem patron
/// modunda kullanılır; kaydetme işini çağıran taraf verir.
///
///  - [isciKaydi]: patron modunda işçinin kendi girdiği kayıt (karşılaştırma)
///  - [hafta]: Pazar günü için o haftanın 45 saat hesabı (inisiyatif butonu)
///  - Dönüş: "not" -> çağıran taraf not defterini açar
Future<String?> gunPaneliAc(
  BuildContext context, {
  required DateTime tarih,
  required GunKaydi? mevcut,
  required Profil? profil,
  required Future<void> Function(GunKaydi) kaydet,
  required Future<void> Function() sil,
  GunKaydi? isciKaydi,
  HaftaSonucu? hafta,
  bool patronModu = false,
  bool notDefteri = false,
  String? kimin,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => GunPaneli(
      tarih: tarih,
      mevcut: mevcut,
      profil: profil,
      kaydet: kaydet,
      sil: sil,
      isciKaydi: isciKaydi,
      hafta: hafta,
      patronModu: patronModu,
      notDefteri: notDefteri,
      kimin: kimin,
    ),
  );
}

class GunPaneli extends StatefulWidget {
  final DateTime tarih;
  final GunKaydi? mevcut;
  final Profil? profil;
  final Future<void> Function(GunKaydi) kaydet;
  final Future<void> Function() sil;
  final GunKaydi? isciKaydi;
  final HaftaSonucu? hafta;
  final bool patronModu;
  final bool notDefteri;
  final String? kimin;

  const GunPaneli({
    super.key,
    required this.tarih,
    required this.mevcut,
    required this.profil,
    required this.kaydet,
    required this.sil,
    this.isciKaydi,
    this.hafta,
    this.patronModu = false,
    this.notDefteri = false,
    this.kimin,
  });

  @override
  State<GunPaneli> createState() => _GunPaneliState();
}

class _GunPaneliState extends State<GunPaneli> {
  late GunDurumu _durum;
  String? _giris, _cikis;
  double _mesai = 0;
  RaporTuru _raporTuru = RaporTuru.ayakta;
  bool _pazarVer = false;
  late final TextEditingController _not;
  late final bool _yeni;
  bool _kaydediliyor = false;

  bool get _pazar => widget.tarih.weekday == DateTime.sunday;
  double get _gunlukSaat =>
      widget.profil?.gunlukSaat ?? PuantajHesaplamaEngine.varsayilanGunlukSaat;
  double get _mola => widget.profil?.molaSaat ?? 1;

  @override
  void initState() {
    super.initState();
    final k = widget.mevcut;
    _yeni = k == null;
    // Yeni kayıtta Pazar ise "Hafta Tatili", değilse "Geldim" önerilir
    _durum = k?.durum ?? (_pazar ? GunDurumu.haftaTatili : GunDurumu.geldi);
    _not = TextEditingController(text: k?.not ?? '');
    _yukle(k);
    _pazarVer = k?.pazarUcretiVer ?? false;
  }

  void _yukle(GunKaydi? k) {
    if (k == null) return;
    _durum = k.durum;
    _giris = k.giris;
    _cikis = k.cikis;
    _mesai = k.mesaiSaat;
    _raporTuru = k.raporTuru;
  }

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  TimeOfDay _saatOku(String? s, TimeOfDay varsayilan) {
    if (s == null) return varsayilan;
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _saatYaz(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _saatSec({required bool giris}) async {
    final secim = await showTimePicker(
      context: context,
      initialTime: giris
          ? _saatOku(_giris, const TimeOfDay(hour: 8, minute: 0))
          : _saatOku(_cikis, const TimeOfDay(hour: 17, minute: 30)),
      helpText: giris ? 'Giriş saati' : 'Çıkış saati',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (secim == null) return;
    setState(() {
      if (giris) {
        _giris = _saatYaz(secim);
      } else {
        _cikis = _saatYaz(secim);
      }
      // İki saat de girildiyse mesaiyi otomatik öner
      if (_giris != null && _cikis != null) {
        _mesai = GunKaydi.mesaiOner(_giris, _cikis, _gunlukSaat, _mola);
      }
    });
  }

  GunKaydi _olustur() {
    final mesaiVar = _durum.mesaiGirilebilir;
    return GunKaydi(
      tarih: Bicim.anahtar(widget.tarih),
      durum: _durum,
      giris: mesaiVar ? _giris : null,
      cikis: mesaiVar ? _cikis : null,
      mesaiSaat: mesaiVar ? _mesai : 0,
      not: _not.text.trim().isEmpty ? null : _not.text.trim(),
      raporTuru: _raporTuru,
      pazarUcretiVer: _pazar && _pazarVer,
    );
  }

  Future<void> _kaydet([GunKaydi? k]) async {
    if (_kaydediliyor) return;
    setState(() => _kaydediliyor = true);
    await widget.kaydet(k ?? _olustur());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sil() async {
    await widget.sil();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final p = widget.profil;
    final sure = GunKaydi.sureHesapla(_giris, _cikis);
    final h = widget.hafta;
    final kesintiAcik = p?.pazarKesintisi ?? true;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.kimin != null)
              Text(widget.kimin!,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: renk.primary)),
            Text(Bicim.uzunTarih(widget.tarih),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),

            // ---- İşçinin kendi kaydı (patron modu)
            if (widget.patronModu) ...[
              _isciKutusu(renk),
              const SizedBox(height: 14),
            ],

            // ---- Durum seçimi (pastel kutular)
            LayoutBuilder(builder: (context, k) {
              final sutun = k.maxWidth > 420 ? 4 : 2;
              final genislik = (k.maxWidth - (sutun - 1) * 8) / sutun;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in GunDurumu.values)
                    SizedBox(width: genislik, child: _durumButonu(d, renk)),
                ],
              );
            }),

            // ---- Pazar: 45 saat ve patron inisiyatifi
            if (_pazar && h != null && h.kayitVar && kesintiAcik) ...[
              const SizedBox(height: 14),
              _haftaKutusu(h, renk),
            ],

            // ---- Pazar çalışması bilgisi
            if (_pazar &&
                p != null &&
                (_durum == GunDurumu.geldi || _durum == GunDurumu.yarimGun)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: GunDurumu.geldi.renk.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Pazar çalışması (${p.pazarEtiketi}): hafta tatili ücreti + '
                  '${Bicim.sayi(p.pazarEkYevmiye * (_durum == GunDurumu.yarimGun ? 0.5 : 1))} yevmiye ek = '
                  '${Bicim.para(p.gunlukUcret * p.pazarEkYevmiye * (_durum == GunDurumu.yarimGun ? 0.5 : 1))}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (!_pazar && kesintiAcik &&
                (_durum == GunDurumu.gelmedi || _durum == GunDurumu.yarimGun)) ...[
              const SizedBox(height: 10),
              Text(
                'Haftalık 45 saat tamamlanmazsa bu haftanın pazar ücreti kesilir. '
                'Mazeretliyse "Ücretli İzin", "Ücretsiz İzin" veya "Raporlu" seçin.',
                style: TextStyle(fontSize: 12, color: renk.error),
              ),
            ],

            // ---- Rapor türü (SGK rapor parası hesabı için)
            if (_durum == GunDurumu.raporlu) ...[
              const SizedBox(height: 16),
              Text('Rapor türü', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<RaporTuru>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: RaporTuru.ayakta, label: Text('Ayakta')),
                  ButtonSegment(value: RaporTuru.yatarak, label: Text('Yatarak')),
                  ButtonSegment(value: RaporTuru.isKazasi, label: Text('İş kazası')),
                ],
                selected: {_raporTuru},
                onSelectionChanged: (s) => setState(() => _raporTuru = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _raporTuru == RaporTuru.isKazasi
                    ? 'İş kazasında SGK 1. günden itibaren günlük kazancın 2/3\'ünü öder.'
                    : 'Hastalıkta SGK ilk 2 günü ödemez; 3. günden itibaren günlük kazancın '
                        '${_raporTuru == RaporTuru.yatarak ? '1/2\'sini (yatarak)' : '2/3\'ünü (ayakta)'} öder.',
                style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
              ),
            ],

            // ---- Giriş / çıkış ve mesai (sadece çalışılan günlerde)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: !_durum.mesaiGirilebilir
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        Row(children: [
                          Expanded(child: _saatKutusu('Giriş', _giris, true)),
                          const SizedBox(width: 10),
                          Expanded(child: _saatKutusu('Çıkış', _cikis, false)),
                        ]),
                        if (sure != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              'Toplam ${Bicim.sayi(sure)} saat '
                              '(mola ${Bicim.sayi(_mola)} sa, normal ${Bicim.sayi(_gunlukSaat)} sa)',
                              style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _mesaiKutusu(renk),
                        if (p != null && _mesai > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              'Saatlik ${Bicim.para(p.saatlikUcret)} (günlük ÷ ${Bicim.sayi(_gunlukSaat)}) × '
                              '${p.mesaiZamEtiketi} zam = '
                              '${Bicim.para(PuantajHesaplamaEngine.mesaiUcreti(_mesai, p.gunlukUcret, gunlukSaat: _gunlukSaat, katsayi: p.mesaiKatsayisi))}',
                              style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _not,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                hintText: 'Örn: B blok kablo çekimi',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            if (widget.notDefteri)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'not'),
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  label: const Text('Bu güne not defterine not yaz'),
                ),
              ),
            const SizedBox(height: 8),
            Row(children: [
              if (!_yeni)
                TextButton.icon(
                  onPressed: _sil,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Sil'),
                  style: TextButton.styleFrom(foregroundColor: renk.error),
                ),
              const Spacer(),
              Flexible(
                child: FilledButton.icon(
                  onPressed: _kaydediliyor ? null : () => _kaydet(),
                  icon: const Icon(Icons.save),
                  label: const Text('Kaydet'),
                  style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _durumButonu(GunDurumu d, ColorScheme renk) {
    final secili = _durum == d;
    final koyu = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: secili ? d.renk : d.pastel(koyu: koyu, zemin: renk.surface),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _durum = d),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(children: [
            Icon(d.ikon, size: 20, color: secili ? Colors.white : d.renk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _pazar && d == GunDurumu.geldi ? 'Pazar çalıştım' : d.etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: secili ? Colors.white : null,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _haftaKutusu(HaftaSonucu h, ColorScheme renk) {
    final tamam = h.tamamlandi;
    final yazi = 'Bu hafta ${Bicim.sayi(h.calisilanSaat)} / ${Bicim.sayi(h.gerekenSaat)} saat'
        '${tamam ? ' • pazar ücreti hak edildi' : ' • ${Bicim.sayi(h.eksikSaat)} saat eksik'}';
    return Container(
      decoration: BoxDecoration(
        color: (tamam ? GunDurumu.geldi.renk : const Color(0xFFEF6C00)).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(tamam ? Icons.verified : Icons.schedule,
                size: 18, color: tamam ? GunDurumu.geldi.renk : const Color(0xFFEF6C00)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(yazi,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
          if (!tamam)
            SwitchListTile(
              contentPadding: const EdgeInsets.only(right: 8),
              value: _pazarVer,
              onChanged: (v) => setState(() => _pazarVer = v),
              title: Text(
                widget.patronModu
                    ? 'Patron İnisiyatifi: Pazar Ücretini Ver'
                    : 'Patronum pazar ücretini verdi',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _pazarVer
                    ? '45 saat dolmasa da bu haftanın pazar ücreti ödenir.'
                    : 'Kapalıyken pazar ücreti kesilir.',
                style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _isciKutusu(ColorScheme renk) {
    final w = widget.isciKaydi;
    final m = widget.mevcut;
    final uyusmazlik = PuantajHesaplamaEngine.karsilastir(m, w);
    const turuncu = Color(0xFFEF6C00);
    final String yazi;
    if (w == null) {
      yazi = 'İşçi bu günü girmemiş';
    } else {
      yazi = 'İşçinin kaydı: ${_pazar && w.durum == GunDurumu.geldi ? 'Pazar çalıştı' : w.durum.etiket}'
          '${w.mesaiSaat > 0 ? ' • +${Bicim.sayi(w.mesaiSaat)} sa mesai' : ''}'
          '${w.giris != null ? ' • ${w.giris}-${w.cikis ?? '--:--'}' : ''}';
    }
    final farkli = uyusmazlik == Uyusmazlik.farkli || uyusmazlik == Uyusmazlik.patronGirmedi;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      decoration: BoxDecoration(
        color: farkli ? turuncu.withValues(alpha: 0.10) : renk.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: farkli ? Border.all(color: turuncu.withValues(alpha: 0.6)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(farkli ? Icons.compare_arrows : Icons.visibility_outlined,
                size: 18, color: farkli ? turuncu : renk.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(yazi, style: const TextStyle(fontSize: 13))),
          ]),
          if (uyusmazlik == Uyusmazlik.farkli)
            const Padding(
              padding: EdgeInsets.only(left: 26, top: 2),
              child: Text('Sizin kaydınızla uyuşmuyor',
                  style: TextStyle(fontSize: 12, color: turuncu, fontWeight: FontWeight.w600)),
            ),
          if (w != null && uyusmazlik != null)
            Wrap(spacing: 4, children: [
              TextButton.icon(
                onPressed: () => setState(() => _yukle(w)),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Forma aktar'),
              ),
              TextButton.icon(
                onPressed: _kaydediliyor
                    ? null
                    : () => _kaydet(w.copyWith(pazarUcretiVer: _pazar && _pazarVer)),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Kabul et ve kaydet'),
              ),
            ])
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _saatTemizle(bool giris) {
    setState(() {
      if (giris) {
        _giris = null;
      } else {
        _cikis = null;
      }
    });
  }

  Widget _saatKutusu(String baslik, String? deger, bool giris) {
    final renk = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _saatSec(giris: giris),
      onLongPress: () => _saatTemizle(giris),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: baslik,
          prefixIcon: Icon(giris ? Icons.login : Icons.logout),
          suffixIcon: deger == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _saatTemizle(giris),
                ),
        ),
        child: Text(
          deger ?? '--:--',
          style: TextStyle(
            fontSize: 16,
            color: deger == null ? renk.outline : null,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _mesaiKutusu(ColorScheme renk) {
    const mor = Color(0xFF6A1B9A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: mor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.more_time, color: mor),
        const SizedBox(width: 10),
        const Expanded(
            child: Text('Fazla mesai', style: TextStyle(fontWeight: FontWeight.w600))),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _mesai >= 0.5 ? () => setState(() => _mesai -= 0.5) : null,
        ),
        SizedBox(
          width: 64,
          child: Text(
            _mesai == 0 ? 'Yok' : '${Bicim.sayi(_mesai)} sa',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: mor),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _mesai < 24 ? () => setState(() => _mesai += 0.5) : null,
        ),
      ]),
    );
  }
}
