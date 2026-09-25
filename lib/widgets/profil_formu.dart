import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profil.dart';
import '../services/bicim.dart';
import '../services/hesaplama.dart';

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
  late final TextEditingController _ad,
      _gorev,
      _firma,
      _ucret,
      _saat,
      _mola,
      _banka,
      _sgkBrut;
  late BankaTipi _bankaTipi;
  late double _haciz;
  late bool _raporTam;
  late double _mesaiKatsayi; // 1.25 / 1.30 / 1.50
  late double _pazarEk; // 1 / 1.5 / 2
  late bool _pazarKesintisi;
  bool _gelismis = false;
  bool _kaydediliyor = false;

  static String _tutarYazi(double v) =>
      v == 0 ? '' : Bicim.sayi(v).replaceAll('.', '');

  @override
  void initState() {
    super.initState();
    final p = widget.baslangic;
    _ad = TextEditingController(text: p?.adSoyad ?? '');
    _gorev = TextEditingController(text: p?.gorev ?? '');
    _firma = TextEditingController(text: p?.firma ?? '');
    _ucret = TextEditingController(text: _tutarYazi(p?.ucret ?? 0));
    _saat = TextEditingController(text: Bicim.sayi(p?.gunlukSaat ?? 7.5));
    _mola = TextEditingController(text: Bicim.sayi(p?.molaSaat ?? 1));
    _banka = TextEditingController(text: _tutarYazi(p?.bankaTutar ?? 0));
    _sgkBrut = TextEditingController(text: _tutarYazi(p?.sgkBrut ?? 0));
    _bankaTipi = p?.bankaTipi ?? BankaTipi.yok;
    _haciz = p?.hacizOrani ?? 0;
    _raporTam = p?.raporTamOdenir ?? true;
    _mesaiKatsayi = p?.mesaiKatsayisi ?? 1.5;
    // Listede olmayan eski değerleri en yakın seçeneğe yuvarla
    if (![1.25, 1.30, 1.50].any((v) => (v - _mesaiKatsayi).abs() < 0.001)) {
      _mesaiKatsayi = 1.5;
    }
    _pazarEk = p?.pazarEkYevmiye ?? 2;
    if (![1.0, 1.5, 2.0].contains(_pazarEk)) _pazarEk = 2;
    _pazarKesintisi = p?.pazarKesintisi ?? true;
    _ucret.addListener(() => setState(() {}));
    _banka.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_ad, _gorev, _firma, _ucret, _saat, _mola, _banka, _sgkBrut]) {
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
      // Uygulama aylıkçı çalışanlar içindir (maaş ÷ 30)
      ucretTipi: UcretTipi.aylik,
      ucret: Bicim.sayiOku(_ucret.text) ?? 0,
      gunlukSaat: Bicim.sayiOku(_saat.text) ?? 7.5,
      mesaiKatsayisi: _mesaiKatsayi,
      pazarEkYevmiye: _pazarEk,
      pazarKesintisi: _pazarKesintisi,
      molaSaat: Bicim.sayiOku(_mola.text) ?? 1,
      bankaTipi: _bankaTipi,
      bankaTutar:
          _bankaTipi == BankaTipi.ozel ? (Bicim.sayiOku(_banka.text) ?? 0) : 0,
      hacizOrani: _bankaTipi == BankaTipi.yok ? 0 : _haciz,
      raporTamOdenir: _raporTam,
      sgkBrut: Bicim.sayiOku(_sgkBrut.text) ?? 0,
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
    final renk = Theme.of(context).colorScheme;
    final ucret = Bicim.sayiOku(_ucret.text);
    final asgari = AsgariUcret.yil(DateTime.now().year);
    const bosluk = SizedBox(height: 14);
    const sayiKlavye = TextInputType.numberWithOptions(decimal: true);
    final sayiFiltre = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final aciklamaStil = TextStyle(fontSize: 12, color: renk.onSurfaceVariant);

    Widget baslik(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 8),
          child: Text(t, style: Theme.of(context).textTheme.titleSmall),
        );

    // Bankaya yatacak 30 günlük tutar ve elden kalan (bilgi amaçlı)
    final bankaAylik = switch (_bankaTipi) {
      BankaTipi.yok => 0.0,
      BankaTipi.asgari => asgari.net,
      BankaTipi.ozel => Bicim.sayiOku(_banka.text) ?? 0.0,
    };

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
          TextFormField(
            controller: _ucret,
            keyboardType: sayiKlavye,
            inputFormatters: sayiFiltre,
            decoration: InputDecoration(
              labelText: 'Aylık toplam maaşınız (₺) *',
              prefixIcon: const Icon(Icons.payments_outlined),
              helperText: ucret != null && ucret > 0
                  ? 'Günlük karşılığı: ${Bicim.para(ucret / 30)}  (maaş ÷ 30) • banka + elden toplamı'
                  : 'Bankaya yatan ve elden verilen toplam',
            ),
            validator: (v) {
              final d = Bicim.sayiOku(v ?? '');
              if (d == null || d <= 0) return 'Ücret girin';
              return null;
            },
          ),

          // ------------------------------------------------------------------
          baslik('Bankaya yatan maaş'),
          SegmentedButton<BankaTipi>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: BankaTipi.yok, label: Text('Yok')),
              ButtonSegment(value: BankaTipi.asgari, label: Text('Asgari')),
              ButtonSegment(value: BankaTipi.ozel, label: Text('Anlaşılan')),
            ],
            selected: {_bankaTipi},
            onSelectionChanged: (s) => setState(() => _bankaTipi = s.first),
          ),
          const SizedBox(height: 8),
          if (_bankaTipi == BankaTipi.yok)
            Text('Maaşın tamamı elden ödenir.', style: aciklamaStil),
          if (_bankaTipi == BankaTipi.asgari)
            Text(
              '${asgari.yil} net asgari ücret bankaya yatar: '
              '${Bicim.para(asgari.net)} (30 gün). Eksik günlerde gün hesabıyla azalır.',
              style: aciklamaStil,
            ),
          if (_bankaTipi == BankaTipi.ozel) ...[
            const SizedBox(height: 4),
            TextFormField(
              controller: _banka,
              keyboardType: sayiKlavye,
              inputFormatters: sayiFiltre,
              decoration: const InputDecoration(
                labelText: 'Bankaya yatan (30 gün, net ₺) *',
                prefixIcon: Icon(Icons.account_balance),
                helperText: 'Firma ile anlaşılan, 30 gün çalışınca bankaya yatan tutar',
              ),
              validator: (v) {
                if (_bankaTipi != BankaTipi.ozel) return null;
                final d = Bicim.sayiOku(v ?? '');
                if (d == null || d <= 0) return 'Bankaya yatan tutarı girin';
                return null;
              },
            ),
          ],
          if (bankaAylik > 0 && ucret != null && ucret > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: renk.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '30 gün tam çalışınca:  Banka ${Bicim.para(bankaAylik)}  •  '
                'Elden ${Bicim.para(ucret - bankaAylik)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          // ------------------------------------------------------------------
          if (_bankaTipi != BankaTipi.yok) ...[
            baslik('Haciz (icra) kesintisi'),
            SegmentedButton<double>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Yok')),
                ButtonSegment(value: 0.25, label: Text('1/4')),
                ButtonSegment(value: 0.10, label: Text('1/10')),
              ],
              selected: {_haciz},
              onSelectionChanged: (s) => setState(() => _haciz = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              _haciz == 0
                  ? 'Maaş haczi yok.'
                  : 'Bankaya yatan tutarın ${_haciz == 0.25 ? 'dörtte biri' : 'onda biri'} '
                      'kesilip icraya gönderilir.',
              style: aciklamaStil,
            ),
          ],

          // ------------------------------------------------------------------
          baslik('Akşam (fazla) mesaisi zammı'),
          SegmentedButton<double>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1.25, label: Text('%25')),
              ButtonSegment(value: 1.30, label: Text('%30')),
              ButtonSegment(value: 1.50, label: Text('%50')),
            ],
            selected: {_mesaiKatsayi},
            onSelectionChanged: (s) => setState(() => _mesaiKatsayi = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            ucret != null && ucret > 0
                ? 'Saatlik ${Bicim.para(ucret / 30 / (Bicim.sayiOku(_saat.text) ?? 7.5))} → '
                    '1 saat mesai ${Bicim.para(ucret / 30 / (Bicim.sayiOku(_saat.text) ?? 7.5) * _mesaiKatsayi)}'
                : 'Saatlik ücret = günlük ücret ÷ 7,5 saat',
            style: aciklamaStil,
          ),

          // ------------------------------------------------------------------
          baslik('Pazar çalışması'),
          SegmentedButton<double>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text("1'e 1")),
              ButtonSegment(value: 1.5, label: Text("1'e 1,5")),
              ButtonSegment(value: 2, label: Text("1'e 2")),
            ],
            selected: {_pazarEk},
            onSelectionChanged: (s) => setState(() => _pazarEk = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            ucret != null && ucret > 0
                ? 'Pazar ücreti ${Bicim.para(ucret / 30)} her hafta ödenir. Pazar çalışınca '
                    '+${Bicim.para(ucret / 30 * _pazarEk)} ek → toplam ${Bicim.para(ucret / 30 * (1 + _pazarEk))}'
                : 'Pazar ücreti her hafta ödenir; pazar çalışınca ayrıca ek yevmiye verilir.',
            style: aciklamaStil,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pazarKesintisi,
            onChanged: (v) => setState(() => _pazarKesintisi = v),
            title: const Text('Mazeretsiz gelmediği haftanın pazarı kesilsin'),
            subtitle: Text(
              'Haftada 45 saat (6 gün) çalışmayan, o hafta "Gelmedim" günü olan işçinin '
              'hafta tatili ücreti ödenmez. İzin, rapor ve resmi tatil mazeret sayılır.',
              style: aciklamaStil,
            ),
          ),

          // ------------------------------------------------------------------
          baslik('Raporlu günler'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _raporTam,
            onChanged: (v) => setState(() => _raporTam = v),
            title: const Text('Raporlu günlerde maaşım tam ödenir'),
            subtitle: Text(
              _raporTam
                  ? 'SGK rapor parasını kendisi yatırır; aradaki farkı işveren maaşım üzerinden öder.'
                  : 'Raporlu günler maaştan düşülür; o günler için sadece SGK öder.',
              style: aciklamaStil,
            ),
          ),

          const SizedBox(height: 4),
          // Gelişmiş ayarlar: çoğu kişi için varsayılanlar doğrudur
          InkWell(
            onTap: () => setState(() => _gelismis = !_gelismis),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(_gelismis ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 6),
                const Text('Diğer ayarlar (saat, mola, SGK)'),
                const Spacer(),
                if (!_gelismis)
                  Text('${_saat.text} saat',
                      style: TextStyle(color: renk.onSurfaceVariant)),
              ]),
            ),
          ),
          if (_gelismis) ...[
            TextFormField(
              controller: _saat,
              keyboardType: sayiKlavye,
              inputFormatters: sayiFiltre,
              decoration: const InputDecoration(
                  labelText: 'Günlük normal çalışma', suffixText: 'saat',
                  helperText: 'Haftalık 45 saat ÷ 6 gün = 7,5 saat'),
              validator: _pozitif,
            ),
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
            bosluk,
            TextFormField(
              controller: _sgkBrut,
              keyboardType: sayiKlavye,
              inputFormatters: sayiFiltre,
              decoration: InputDecoration(
                labelText: 'SGK\'ya bildirilen brüt maaş (30 gün)',
                prefixIcon: const Icon(Icons.health_and_safety_outlined),
                helperText:
                    'Rapor parası hesabı için. Boş bırakılırsa brüt asgari ücret (${Bicim.para(asgari.brut)}) alınır.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 6),
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
