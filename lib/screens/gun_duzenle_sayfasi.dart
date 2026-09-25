import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/gun_kaydi.dart';
import '../services/bicim.dart';
import 'notlar_sayfasi.dart';

/// Bir günün kaydını açılır alt pencerede düzenler.
/// Pencereden "Bu güne not yaz" seçilirse not defteri o tarihle açılır.
Future<void> gunDuzenle(BuildContext context, DateTime tarih) async {
  final sonuc = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => GunDuzenlePenceresi(tarih: tarih),
  );
  if (sonuc == 'not' && context.mounted) {
    await notDuzenle(context, tarih: tarih);
  }
}

class GunDuzenlePenceresi extends StatefulWidget {
  final DateTime tarih;
  const GunDuzenlePenceresi({super.key, required this.tarih});

  @override
  State<GunDuzenlePenceresi> createState() => _GunDuzenlePenceresiState();
}

class _GunDuzenlePenceresiState extends State<GunDuzenlePenceresi> {
  final _depo = Depo.instance;
  late GunDurumu _durum;
  String? _giris, _cikis;
  double _mesai = 0;
  RaporTuru _raporTuru = RaporTuru.ayakta;
  late final TextEditingController _not;
  late final bool _yeni;

  @override
  void initState() {
    super.initState();
    final k = _depo.gun(widget.tarih);
    _yeni = k == null;
    // Yeni kayıtta Pazar ise "Hafta Tatili", değilse "Geldim" önerilir
    _durum = k?.durum ??
        (widget.tarih.weekday == DateTime.sunday
            ? GunDurumu.haftaTatili
            : GunDurumu.geldi);
    _giris = k?.giris;
    _cikis = k?.cikis;
    _mesai = k?.mesaiSaat ?? 0;
    _raporTuru = k?.raporTuru ?? RaporTuru.ayakta;
    _not = TextEditingController(text: k?.not ?? '');
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
        final p = _depo.profil!;
        _mesai = GunKaydi.mesaiOner(_giris, _cikis, p.gunlukSaat, p.molaSaat);
      }
    });
  }

  Future<void> _kaydet() async {
    final mesaiVar = _durum.mesaiGirilebilir;
    await _depo.gunKaydet(GunKaydi(
      tarih: Bicim.anahtar(widget.tarih),
      durum: _durum,
      giris: mesaiVar ? _giris : null,
      cikis: mesaiVar ? _cikis : null,
      mesaiSaat: mesaiVar ? _mesai : 0,
      not: _not.text.trim().isEmpty ? null : _not.text.trim(),
      raporTuru: _raporTuru,
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sil() async {
    await _depo.gunSil(Bicim.anahtar(widget.tarih));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final p = _depo.profil!;
    final sure = GunKaydi.sureHesapla(_giris, _cikis);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Bicim.uzunTarih(widget.tarih),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),

            // ---- Durum seçimi
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in GunDurumu.values)
                  ChoiceChip(
                    label: Text(d.etiket),
                    avatar: Icon(d.ikon,
                        size: 18, color: _durum == d ? Colors.white : d.renk),
                    selected: _durum == d,
                    selectedColor: d.renk,
                    labelStyle:
                        TextStyle(color: _durum == d ? Colors.white : null),
                    onSelected: (_) => setState(() => _durum = d),
                  ),
              ],
            ),

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
                              '(mola ${Bicim.sayi(p.molaSaat)} sa, normal ${Bicim.sayi(p.gunlukSaat)} sa)',
                              style: TextStyle(
                                  fontSize: 12, color: renk.onSurfaceVariant),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _mesaiKutusu(renk),
                        if (_durum == GunDurumu.haftaTatili ||
                            _durum == GunDurumu.resmiTatil)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              'Tatilde çalıştıysanız çalıştığınız saati mesai olarak girin.',
                              style: TextStyle(
                                  fontSize: 12, color: renk.onSurfaceVariant),
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
                  label: const Text('Kaydı sil'),
                  style: TextButton.styleFrom(foregroundColor: renk.error),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _kaydet,
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
              ),
            ]),
          ],
        ),
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
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: mor),
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
