import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/not_kaydi.dart';
import '../services/bicim.dart';
import '../services/paylasim.dart';
import '../widgets/ay_gezgini.dart';

/// Not defteri: her not bir tarihe kaydedilir, tek tek veya aylık toplu
/// olarak WhatsApp'tan gönderilebilir.
class NotlarSayfasi extends StatelessWidget {
  const NotlarSayfasi({super.key});

  /// Tek bir notun paylaşım metni
  static String notMetni(NotKaydi n) {
    final ad = Depo.instance.profil?.adSoyad ?? '';
    return '📅 ${Bicim.uzunTarih(Bicim.anahtarOku(n.tarih))}'
        '${n.saat.isEmpty ? '' : '  🕒 ${n.saat}'}\n\n'
        '${n.metin.trim()}'
        '${ad.isEmpty ? '' : '\n\n— $ad'}';
  }

  /// Bir ayın tüm notlarının paylaşım metni (günlere göre gruplu)
  static String ayMetni(DateTime ay, List<NotKaydi> notlar) {
    final ad = Depo.instance.profil?.adSoyad ?? '';
    final b = StringBuffer('📒 ${ad.isEmpty ? '' : '$ad - '}${Bicim.ay(ay)} Notları\n');
    String? sonGun;
    for (final n in notlar) {
      if (n.tarih != sonGun) {
        b.write('\n📅 ${Bicim.gunAy(Bicim.anahtarOku(n.tarih))}\n');
        sonGun = n.tarih;
      }
      final satirlar = n.metin.trim().split('\n');
      b.write('• ${satirlar.first}\n');
      for (final s in satirlar.skip(1)) {
        if (s.trim().isNotEmpty) b.write('   $s\n');
      }
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([depo, depo.seciliAy]),
      builder: (context, _) {
        final ay = depo.seciliAy.value;
        final notlar = depo.ayNotlari(ay);
        final renk = Theme.of(context).colorScheme;

        // Günlere göre grupla (yeni gün üstte)
        final gunler = <String, List<NotKaydi>>{};
        for (final n in notlar.reversed) {
          gunler.putIfAbsent(n.tarih, () => []).add(n);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Not Defterim'),
            actions: [
              if (notlar.isNotEmpty)
                Builder(
                  builder: (btnCtx) => IconButton(
                    tooltip: 'Bu ayın tüm notlarını gönder',
                    icon: const Icon(Icons.share),
                    onPressed: () => Paylasim.metinPaylas(
                      btnCtx,
                      ayMetni(ay, notlar),
                      konu: '${Bicim.ay(ay)} notları',
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => notDuzenle(context),
            icon: const Icon(Icons.edit_note),
            label: const Text('Not Yaz'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const AyGezgini(),
              if (notlar.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.sticky_note_2_outlined,
                        size: 56, color: renk.outline),
                    const SizedBox(height: 12),
                    Text('Bu ay için not yok',
                        style: TextStyle(color: renk.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      'Yapılan işi, malzemeyi, konuşulanları yazın;\n'
                      'o güne kaydedilir, istediğinizde WhatsApp\'tan gönderin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: renk.outline),
                    ),
                  ]),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    '${notlar.length} not • ${gunler.length} gün',
                    style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
                  ),
                ),
              for (final e in gunler.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    Bicim.uzunTarih(Bicim.anahtarOku(e.key)),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: renk.primary),
                  ),
                ),
                for (final n in e.value) _NotKarti(not: n),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NotKarti extends StatelessWidget {
  final NotKaydi not;
  const _NotKarti({required this.not});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => notDuzenle(context, mevcut: not),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(not.baslik,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    if (not.devami.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        not.devami,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: renk.onSurfaceVariant),
                      ),
                    ],
                    if (not.saat.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('🕒 ${not.saat}',
                          style: TextStyle(fontSize: 11.5, color: renk.outline)),
                    ],
                  ],
                ),
              ),
              Builder(
                builder: (btnCtx) => IconButton(
                  tooltip: 'WhatsApp ile gönder',
                  icon: Icon(Icons.send, color: renk.primary),
                  onPressed: () => Paylasim.metinPaylas(
                      btnCtx, NotlarSayfasi.notMetni(not),
                      konu: 'Not'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Not yazma / düzenleme penceresi.
/// [tarih] verilirse yeni not o güne yazılır (takvimden açıldığında).
Future<void> notDuzenle(BuildContext context,
    {NotKaydi? mevcut, DateTime? tarih}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _NotFormu(mevcut: mevcut, tarih: tarih),
  );
}

class _NotFormu extends StatefulWidget {
  final NotKaydi? mevcut;
  final DateTime? tarih;
  const _NotFormu({this.mevcut, this.tarih});

  @override
  State<_NotFormu> createState() => _NotFormuState();
}

class _NotFormuState extends State<_NotFormu> {
  late DateTime _tarih;
  late final TextEditingController _metin;

  @override
  void initState() {
    super.initState();
    final m = widget.mevcut;
    _tarih = m != null
        ? Bicim.anahtarOku(m.tarih)
        : Bicim.sadeceGun(widget.tarih ?? DateTime.now());
    _metin = TextEditingController(text: m?.metin ?? '');
    _metin.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _metin.dispose();
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

  NotKaydi _notOlustur() {
    final simdi = DateTime.now();
    final m = widget.mevcut;
    return NotKaydi(
      id: m?.id ?? simdi.microsecondsSinceEpoch.toString(),
      tarih: Bicim.anahtar(_tarih),
      saat: m?.saat ??
          '${simdi.hour.toString().padLeft(2, '0')}:${simdi.minute.toString().padLeft(2, '0')}',
      metin: _metin.text.trim(),
    );
  }

  Future<void> _kaydet({bool gonder = false, BuildContext? btnCtx}) async {
    if (_metin.text.trim().isEmpty) return;
    final n = _notOlustur();
    // Kaydı başlat; paylaşım menüsü dokunuşa hemen yanıt vermeli (iPhone için)
    final kayit = Depo.instance.notKaydet(n);
    if (gonder && btnCtx != null) {
      await Paylasim.metinPaylas(btnCtx, NotlarSayfasi.notMetni(n), konu: 'Not');
    }
    await kayit;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sil() async {
    await Depo.instance.notSil(widget.mevcut!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final bos = _metin.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.mevcut == null ? 'Yeni Not' : 'Notu Düzenle',
                style: Theme.of(context).textTheme.titleLarge),
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
              controller: _metin,
              autofocus: widget.mevcut == null,
              minLines: 6,
              maxLines: 14,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Notunuzu yazın...\n\n'
                    'Örn: B blok 3. kat kablo çekimi bitti.\n'
                    'Yarın 2 top NYM 3x2,5 lazım.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              if (widget.mevcut != null)
                IconButton(
                  tooltip: 'Notu sil',
                  onPressed: _sil,
                  icon: Icon(Icons.delete_outline, color: renk.error),
                ),
              const Spacer(),
              Builder(
                builder: (btnCtx) => OutlinedButton.icon(
                  onPressed: bos ? null : () => _kaydet(gonder: true, btnCtx: btnCtx),
                  icon: const Icon(Icons.send),
                  label: const Text('Gönder'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: bos ? null : () => _kaydet(),
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
