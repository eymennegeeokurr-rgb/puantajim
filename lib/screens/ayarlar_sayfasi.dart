import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../services/bicim.dart';
import '../services/paylasim.dart';
import '../widgets/profil_formu.dart';

/// Profil bilgileri, tema, yedekleme.
class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  void _mesaj(BuildContext c, String m) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  Uint8List _yedekVerisi() =>
      Uint8List.fromList(utf8.encode(Depo.instance.yedekOlustur()));

  String get _yedekAdi =>
      'Puantajim_yedek_${Bicim.dosyaAdi(Depo.instance.profil?.adSoyad ?? '')}_${Bicim.anahtar(DateTime.now())}.json';

  Future<void> _geriYukle(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: const Text('Yedekten geri yüklensin mi?'),
        content: const Text(
            'Bu telefondaki tüm kayıtlar, seçeceğiniz yedek dosyasındakilerle DEĞİŞTİRİLECEK.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Dosya Seç')),
        ],
      ),
    );
    if (onay != true) return;

    final sonuc =
        await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    final veri = sonuc?.files.single.bytes;
    if (veri == null) return;
    try {
      await Depo.instance.yedektenYukle(utf8.decode(veri));
      if (context.mounted) _mesaj(context, 'Yedek geri yüklendi');
    } catch (e) {
      if (context.mounted) _mesaj(context, 'Geri yüklenemedi: $e');
    }
  }

  Future<void> _tumunuSil(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever),
        title: const Text('Tüm veriler silinsin mi?'),
        content: const Text(
            'Profil, bütün puantaj ve avans kayıtları kalıcı olarak silinir. '
            'Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hepsini Sil'),
          ),
        ],
      ),
    );
    if (onay == true) await Depo.instance.tumunuSil();
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    final renk = Theme.of(context).colorScheme;
    Widget baslik(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: Text(t,
              style: TextStyle(color: renk.primary, fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Profil ve Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          baslik('Bilgilerim'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListenableBuilder(
              listenable: depo,
              // Profil değişince form yeniden kurulsun (yedek geri yükleme sonrası)
              builder: (_, __) => ProfilFormu(
                key: ValueKey(depo.profil?.toJson().toString()),
                baslangic: depo.profil,
                butonYazisi: 'Bilgilerimi Kaydet',
                kaydet: (p) async {
                  await depo.profilKaydet(p);
                  if (context.mounted) _mesaj(context, 'Bilgileriniz kaydedildi');
                },
              ),
            ),
          ),
          baslik('Görünüm'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: depo.temaModu,
              builder: (_, mod, __) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Açık')),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('Sistem')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Koyu')),
                ],
                selected: {mod},
                onSelectionChanged: (s) => depo.temaAyarla(s.first),
              ),
            ),
          ),
          baslik('Yedekleme'),
          Card(
            child: Column(children: [
              Builder(
                builder: (btnCtx) => ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Yedek al ve gönder'),
                  subtitle: const Text(
                      'Tüm kayıtları tek dosya olarak WhatsApp\'a, Drive\'a veya kendinize gönderin'),
                  onTap: () async {
                    try {
                      await Paylasim.paylas(btnCtx, _yedekVerisi(), _yedekAdi,
                          Paylasim.jsonMime, 'Puantajım yedeği');
                    } catch (_) {
                      await Paylasim.kaydet(
                          _yedekVerisi(), _yedekAdi, Paylasim.jsonMime);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Yedeği cihaza kaydet'),
                onTap: () async {
                  final ok = await Paylasim.kaydet(
                      _yedekVerisi(), _yedekAdi, Paylasim.jsonMime);
                  if (ok && context.mounted) _mesaj(context, 'Yedek kaydedildi');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('Yedekten geri yükle'),
                subtitle: const Text('Daha önce aldığınız .json yedek dosyasını seçin'),
                onTap: () => _geriYukle(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'Kayıtlarınız yalnızca bu telefonda durur, internete gönderilmez. '
              'Telefon değiştirmeden veya uygulamayı silmeden önce mutlaka yedek alın. '
              'Ayda bir yedeği kendinize WhatsApp\'tan göndermeniz önerilir.',
              style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
            ),
          ),
          baslik('Tehlikeli Bölge'),
          Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: renk.error),
              title: Text('Tüm verileri sil', style: TextStyle(color: renk.error)),
              onTap: () => _tumunuSil(context),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Puantajım v1.0.0',
                style: TextStyle(fontSize: 12, color: renk.outline)),
          ),
        ],
      ),
    );
  }
}
