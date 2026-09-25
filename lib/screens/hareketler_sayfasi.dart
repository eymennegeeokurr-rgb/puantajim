import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/depo.dart';
import '../models/para_hareketi.dart';
import '../services/bicim.dart';
import '../widgets/ay_gezgini.dart';

/// Avans, kesinti ve ek ödemeler (seçili ay).
class HareketlerSayfasi extends StatelessWidget {
  const HareketlerSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Avans ve Ödemeler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => hareketDuzenle(context),
        icon: const Icon(Icons.add),
        label: const Text('Avans Ekle'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([depo, depo.seciliAy]),
        builder: (context, _) {
          final ay = depo.seciliAy.value;
          final liste = depo.ayHareketleri(ay);
          final renk = Theme.of(context).colorScheme;

          double toplam(HareketTuru t) => liste
              .where((h) => h.tur == t)
              .fold<double>(0, (a, h) => a + h.tutar);

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const AyGezgini(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    for (final t in HareketTuru.values)
                      Expanded(
                        child: Column(children: [
                          Text(Bicim.para(toplam(t)),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: t.renk)),
                          const SizedBox(height: 2),
                          Text(t == HareketTuru.ekOdeme ? 'Ek Ödeme' : t.etiket,
                              style: TextStyle(
                                  fontSize: 12, color: renk.onSurfaceVariant)),
                        ]),
                      ),
                  ]),
                ),
              ),
              if (liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.savings_outlined, size: 56, color: renk.outline),
                    const SizedBox(height: 12),
                    Text('Bu ay avans veya ödeme kaydı yok',
                        style: TextStyle(color: renk.onSurfaceVariant)),
                  ]),
                ),
              for (final h in liste)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: h.tur.renk.withValues(alpha: 0.15),
                      child: Icon(h.tur.ikon, color: h.tur.renk),
                    ),
                    title: Text(h.aciklama.isEmpty ? h.tur.etiket : h.aciklama,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${Bicim.kisaTarih(Bicim.anahtarOku(h.tarih))} • ${h.tur.etiket}'),
                    trailing: Text(
                      '${h.tur.isaret > 0 ? '+' : '−'} ${Bicim.para(h.tutar)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: h.tur.renk),
                    ),
                    onTap: () => hareketDuzenle(context, mevcut: h),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Avans / kesinti / ek ödeme ekleme-düzenleme penceresi
Future<void> hareketDuzenle(BuildContext context, {ParaHareketi? mevcut}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _HareketFormu(mevcut: mevcut),
  );
}

class _HareketFormu extends StatefulWidget {
  final ParaHareketi? mevcut;
  const _HareketFormu({this.mevcut});

  @override
  State<_HareketFormu> createState() => _HareketFormuState();
}

class _HareketFormuState extends State<_HareketFormu> {
  final _form = GlobalKey<FormState>();
  late HareketTuru _tur;
  late DateTime _tarih;
  late final TextEditingController _tutar, _aciklama;

  @override
  void initState() {
    super.initState();
    final m = widget.mevcut;
    _tur = m?.tur ?? HareketTuru.avans;
    if (m != null) {
      _tarih = Bicim.anahtarOku(m.tarih);
    } else {
      // Yeni kayıt: seçili ay bu aysa bugün, değilse o ayın 1'i
      final ay = Depo.instance.seciliAy.value;
      final simdi = DateTime.now();
      _tarih = (ay.year == simdi.year && ay.month == simdi.month)
          ? Bicim.sadeceGun(simdi)
          : ay;
    }
    _tutar = TextEditingController(
        text: m == null ? '' : Bicim.sayi(m.tutar).replaceAll('.', ''));
    _aciklama = TextEditingController(text: m?.aciklama ?? '');
  }

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (t != null) setState(() => _tarih = t);
  }

  Future<void> _kaydet() async {
    if (!_form.currentState!.validate()) return;
    await Depo.instance.hareketKaydet(ParaHareketi(
      id: widget.mevcut?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      tarih: Bicim.anahtar(_tarih),
      tur: _tur,
      tutar: Bicim.sayiOku(_tutar.text)!,
      aciklama: _aciklama.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sil() async {
    await Depo.instance.hareketSil(widget.mevcut!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.mevcut == null ? 'Yeni Kayıt' : 'Kaydı Düzenle',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              SegmentedButton<HareketTuru>(
                segments: const [
                  ButtonSegment(value: HareketTuru.avans, label: Text('Avans')),
                  ButtonSegment(value: HareketTuru.kesinti, label: Text('Kesinti')),
                  ButtonSegment(value: HareketTuru.ekOdeme, label: Text('Ek Ödeme')),
                ],
                selected: {_tur},
                onSelectionChanged: (s) => setState(() => _tur = s.first),
              ),
              const SizedBox(height: 6),
              Text(_tur.aciklama,
                  style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _tutar,
                autofocus: widget.mevcut == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: const InputDecoration(
                  labelText: 'Tutar (₺)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final d = Bicim.sayiOku(v ?? '');
                  return (d == null || d <= 0) ? 'Tutar girin' : null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _tarihSec,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tarih',
                    prefixIcon: Icon(Icons.event),
                  ),
                  child: Text(Bicim.uzunTarih(_tarih)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aciklama,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (isteğe bağlı)',
                  hintText: 'Örn: Elden alındı, bayram harçlığı',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                if (widget.mevcut != null)
                  TextButton.icon(
                    onPressed: _sil,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Sil'),
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
      ),
    );
  }
}
