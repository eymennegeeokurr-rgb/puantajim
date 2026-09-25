import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profil.dart';
import '../services/bicim.dart';

/// Profil bilgileri formu (kurulumda ve ayarlarda kullanılır).
class ProfilFormu extends StatefulWidget {
  final Profil? baslangic;
  final String butonYazisi;
  final Future<void> Function(Profil) kaydet;

  const ProfilFormu({
    super.key,
    this.baslangic,
    required this.butonYazisi,
    required this.kaydet,
  });

  @override
  State<ProfilFormu> createState() => _ProfilFormuState();
}

class _ProfilFormuState extends State<ProfilFormu> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _ad, _gorev, _firma, _ucret, _saat, _kat, _mola;
  late UcretTipi _tip;
  bool _gelismis = false;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    final p = widget.baslangic;
    _ad = TextEditingController(text: p?.adSoyad ?? '');
    _gorev = TextEditingController(text: p?.gorev ?? '');
    _firma = TextEditingController(text: p?.firma ?? '');
    _ucret = TextEditingController(
        text: p == null || p.ucret == 0 ? '' : Bicim.sayi(p.ucret).replaceAll('.', ''));
    _saat = TextEditingController(text: Bicim.sayi(p?.gunlukSaat ?? 7.5));
    _kat = TextEditingController(text: Bicim.sayi(p?.mesaiKatsayisi ?? 1.5));
    _mola = TextEditingController(text: Bicim.sayi(p?.molaSaat ?? 1));
    _tip = p?.ucretTipi ?? UcretTipi.aylik;
    _ucret.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_ad, _gorev, _firma, _ucret, _saat, _kat, _mola]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _kaydediliyor = true);
    await widget.kaydet(Profil(
      adSoyad: _ad.text.trim(),
      gorev: _gorev.text.trim(),
      firma: _firma.text.trim(),
      ucretTipi: _tip,
      ucret: Bicim.sayiOku(_ucret.text) ?? 0,
      gunlukSaat: Bicim.sayiOku(_saat.text) ?? 7.5,
      mesaiKatsayisi: Bicim.sayiOku(_kat.text) ?? 1.5,
      molaSaat: Bicim.sayiOku(_mola.text) ?? 1,
    ));
    if (mounted) setState(() => _kaydediliyor = false);
  }

  String? _pozitif(String? v) {
    final d = Bicim.sayiOku(v ?? '');
    if (d == null || d < 0) return 'Geçerli bir sayı girin';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ucret = Bicim.sayiOku(_ucret.text);
    const bosluk = SizedBox(height: 14);
    final sayiKlavye = const TextInputType.numberWithOptions(decimal: true);
    final sayiFiltre = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _ad,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Adınız Soyadınız *', prefixIcon: Icon(Icons.person)),
            validator: (v) =>
                (v == null || v.trim().length < 3) ? 'Ad soyad girin' : null,
          ),
          bosluk,
          TextFormField(
            controller: _gorev,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Göreviniz',
              hintText: 'Örn: Elektrikçi, Usta, Kablocu',
              prefixIcon: Icon(Icons.engineering_outlined),
            ),
          ),
          bosluk,
          TextFormField(
            controller: _firma,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Çalıştığınız firma / şantiye',
              prefixIcon: Icon(Icons.business_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Text('Ücretiniz', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<UcretTipi>(
            segments: const [
              ButtonSegment(
                  value: UcretTipi.aylik,
                  label: Text('Aylık Maaş'),
                  icon: Icon(Icons.calendar_month)),
              ButtonSegment(
                  value: UcretTipi.gunluk,
                  label: Text('Günlük Yevmiye'),
                  icon: Icon(Icons.today)),
            ],
            selected: {_tip},
            onSelectionChanged: (s) => setState(() => _tip = s.first),
          ),
          bosluk,
          TextFormField(
            controller: _ucret,
            keyboardType: sayiKlavye,
            inputFormatters: sayiFiltre,
            decoration: InputDecoration(
              labelText:
                  _tip == UcretTipi.aylik ? 'Aylık maaş (₺) *' : 'Günlük yevmiye (₺) *',
              prefixIcon: const Icon(Icons.payments_outlined),
              helperText: _tip == UcretTipi.aylik && ucret != null && ucret > 0
                  ? 'Günlük karşılığı: ${Bicim.para(ucret / 30)}  (maaş ÷ 30)'
                  : null,
            ),
            validator: (v) {
              final d = Bicim.sayiOku(v ?? '');
              if (d == null || d <= 0) return 'Ücret girin';
              return null;
            },
          ),
          const SizedBox(height: 8),
          // Gelişmiş ayarlar: çoğu kişi için varsayılanlar doğrudur
          InkWell(
            onTap: () => setState(() => _gelismis = !_gelismis),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(_gelismis ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 6),
                const Text('Mesai ayarları'),
                const Spacer(),
                if (!_gelismis)
                  Text(
                    '${_saat.text} saat • ×${_kat.text}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ]),
            ),
          ),
          if (_gelismis) ...[
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _saat,
                  keyboardType: sayiKlavye,
                  inputFormatters: sayiFiltre,
                  decoration: const InputDecoration(
                      labelText: 'Günlük normal', suffixText: 'saat'),
                  validator: _pozitif,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _kat,
                  keyboardType: sayiKlavye,
                  inputFormatters: sayiFiltre,
                  decoration: const InputDecoration(
                      labelText: 'Mesai katsayısı', prefixText: '× '),
                  validator: _pozitif,
                ),
              ),
            ]),
            bosluk,
            TextFormField(
              controller: _mola,
              keyboardType: sayiKlavye,
              inputFormatters: sayiFiltre,
              decoration: const InputDecoration(
                labelText: 'Günlük mola',
                suffixText: 'saat',
                helperText: 'Giriş-çıkış saatinden mesai hesaplanırken düşülür',
              ),
              validator: _pozitif,
            ),
            const SizedBox(height: 6),
            Text(
              'Saatlik ücret = günlük ücret ÷ günlük normal saat. '
              'Mesai ücreti = mesai saati × saatlik ücret × katsayı. '
              'Yasal varsayılan: 7,5 saat ve × 1,5.',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _kaydediliyor ? null : _gonder,
            icon: const Icon(Icons.check),
            label: Text(widget.butonYazisi),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }
}
