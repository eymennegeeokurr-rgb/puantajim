import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/profil.dart';
import '../services/app_mode_controller.dart';
import '../services/bicim.dart';
import '../services/bulut.dart';
import '../services/guncelleme.dart';
import '../services/paylasim.dart';
import '../tema.dart';
import '../widgets/hesabim_karti.dart';
import '../widgets/mod_secici.dart';
import '../widgets/profil_formu.dart';

void _mesaj(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// Profil sekmesi: üstte kişi kartı, altında sade bir menü.
/// Her bölüm kendi sayfasında açılır (bilgilerim, hesabım, mod, yedekleme).
class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  void _ac(BuildContext context, String baslik, Widget icerik) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(baslik)),
        body: icerik,
      ),
    ));
  }

  Future<void> _temaSec(BuildContext context) async {
    final depo = Depo.instance;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: depo.temaModu,
          builder: (_, mod, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (m, ikon, ad) in const [
              (ThemeMode.light, Icons.light_mode_outlined, 'Açık'),
              (ThemeMode.dark, Icons.dark_mode_outlined, 'Koyu'),
              (ThemeMode.system, Icons.brightness_auto_outlined, 'Telefona göre'),
            ])
              ListTile(
                leading: Icon(ikon),
                title: Text(ad),
                trailing: mod == m ? const Icon(Icons.check_circle, color: Renkler.yesil) : null,
                onTap: () {
                  depo.temaAyarla(m);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Future<void> _guncellemeDenetle(BuildContext context) async {
    _mesaj(context, 'Denetleniyor...');
    final yeni = await Guncelleme.kontrolEt();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (yeni != null) {
      await Guncelleme.pencereGoster(context, yeni);
    } else {
      _mesaj(context, 'En güncel sürümü kullanıyorsunuz (veya internet yok)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    final renk = Theme.of(context).colorScheme;
    final girisli = Bulut.oturum.value != null;

    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: const Text('Profil')),
      body: ListenableBuilder(
        listenable: Listenable.merge([depo, depo.temaModu, AppModeController.instance.dinleyici]),
        builder: (context, _) {
          final p = depo.profil;
          final tema = switch (depo.temaModu.value) {
            ThemeMode.light => 'Açık',
            ThemeMode.dark => 'Koyu',
            ThemeMode.system => 'Telefona göre',
          };
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _KisiKarti(
                profil: p,
                onDuzenle: () => _ac(context, 'Bilgilerim', const _BilgilerimIcerik()),
              ),
              _Grup(baslik: 'Hesap', ogeler: [
                if (girisli)
                  _Oge(
                    ikon: Icons.badge_outlined,
                    baslik: 'Hesabım ve kullanıcı kodum',
                    alt: Bulut.oturum.value?.kod,
                    onTap: () => _ac(
                      context,
                      'Hesabım',
                      ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: const [HesabimKarti()],
                      ),
                    ),
                  ),
                if (girisli)
                  _Oge(
                    ikon: AppModeController.instance.patronModu
                        ? Icons.groups_outlined
                        : Icons.person_outline,
                    baslik: 'Uygulama modu',
                    alt: '${AppModeController.instance.etkinMod.etiket} mod',
                    onTap: () => _ac(
                      context,
                      'Uygulama modu',
                      ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: const [ModSeciciKarti()],
                      ),
                    ),
                  ),
                _Oge(
                  ikon: Icons.edit_outlined,
                  baslik: 'Maaş ve hesap ayarları',
                  alt: 'Maaş, banka, yol, mesai, pazar',
                  onTap: () => _ac(context, 'Bilgilerim', const _BilgilerimIcerik()),
                ),
              ]),
              _Grup(baslik: 'Uygulama', ogeler: [
                _Oge(
                  ikon: Icons.palette_outlined,
                  baslik: 'Görünüm',
                  alt: tema,
                  onTap: () => _temaSec(context),
                ),
                _Oge(
                  ikon: Icons.backup_outlined,
                  baslik: 'Yedekleme',
                  alt: 'Yedek al, geri yükle',
                  onTap: () => _ac(context, 'Yedekleme', const _YedekIcerik()),
                ),
                if (Guncelleme.etkin)
                  _Oge(
                    ikon: Icons.system_update_outlined,
                    baslik: 'Güncellemeleri denetle',
                    alt: 'Yüklü sürüm: ${Guncelleme.surumAdi}',
                    onTap: () => _guncellemeDenetle(context),
                  ),
              ]),
              const SizedBox(height: 12),
              Center(
                child: Text('Puantajım ${Guncelleme.surumAdi}',
                    style: TextStyle(fontSize: 12, color: renk.outline)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Parçalar
// =============================================================================

class _KisiKarti extends StatelessWidget {
  final Profil? profil;
  final VoidCallback onDuzenle;
  const _KisiKarti({required this.profil, required this.onDuzenle});

  @override
  Widget build(BuildContext context) {
    final p = profil;
    final ad = p?.adSoyad ?? '';
    final basHarf = ad
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '' : s[0])
        .join()
        .toUpperCase();
    final alt = [
      if (p != null && p.gorev.isNotEmpty) p.gorev,
      if (p != null && p.firma.isNotEmpty) p.firma,
    ].join(' • ');
    final soluk = Colors.white.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Material(
        color: Renkler.lacivert,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onDuzenle,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                child: Text(basHarf.isEmpty ? '?' : basHarf,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.isEmpty ? 'Bilgilerinizi girin' : ad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    if (alt.isNotEmpty)
                      Text(alt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: soluk, fontSize: 13)),
                    if (p != null) ...[
                      const SizedBox(height: 6),
                      Text('Maaş ${Bicim.para(p.ucret)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Düzenle',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Grup extends StatelessWidget {
  final String baslik;
  final List<_Oge> ogeler;
  const _Grup({required this.baslik, required this.ogeler});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    if (ogeler.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
          child: Text(baslik,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: renk.onSurfaceVariant)),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < ogeler.length; i++) ...[
              if (i > 0) Divider(indent: 64, color: renk.outlineVariant),
              ogeler[i],
            ],
          ]),
        ),
      ],
    );
  }
}

class _Oge extends StatelessWidget {
  final IconData ikon;
  final String baslik;
  final String? alt;
  final VoidCallback onTap;
  const _Oge({required this.ikon, required this.baslik, required this.onTap, this.alt});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: renk.surfaceContainerHigh,
        child: Icon(ikon, size: 20, color: renk.onSurface),
      ),
      title: Text(baslik, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
      subtitle: alt == null || alt!.isEmpty
          ? null
          : Text(alt!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// =============================================================================
// Alt sayfalar
// =============================================================================

class _BilgilerimIcerik extends StatelessWidget {
  const _BilgilerimIcerik();

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ListenableBuilder(
          listenable: depo,
          // Profil değişince form yeniden kurulsun (yedek geri yükleme sonrası)
          builder: (_, __) => ProfilFormu(
            key: ValueKey(depo.profil?.toJson().toString()),
            baslangic: depo.profil,
            butonYazisi: 'Kaydet',
            kaydet: (p) async {
              await depo.profilKaydet(p);
              if (context.mounted) {
                _mesaj(context, 'Bilgileriniz kaydedildi');
                Navigator.of(context).maybePop();
              }
            },
          ),
        ),
      ],
    );
  }
}

class _YedekIcerik extends StatelessWidget {
  const _YedekIcerik();

  Uint8List _yedekVerisi() => Uint8List.fromList(utf8.encode(Depo.instance.yedekOlustur()));

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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Dosya Seç')),
        ],
      ),
    );
    if (onay != true) return;
    final dosya = await openFile();
    if (dosya == null) return;
    final veri = await dosya.readAsBytes();
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
        content: Text('Profil, bütün puantaj, avans ve not kayıtları kalıcı olarak silinir'
            '${Bulut.oturum.value != null ? ' (bulut hesabınızdaki kopya dahil)' : ''}. '
            'Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hepsini Sil'),
          ),
        ],
      ),
    );
    if (onay == true) {
      await Depo.instance.tumunuSil();
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Card(
          child: Column(children: [
            Builder(
              builder: (btnCtx) => ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Yedek al ve gönder'),
                subtitle: const Text('WhatsApp\'a, Drive\'a veya kendinize gönderin'),
                onTap: () async {
                  try {
                    await Paylasim.paylas(btnCtx, _yedekVerisi(), _yedekAdi,
                        Paylasim.jsonMime, 'Puantajım yedeği');
                  } catch (_) {
                    await Paylasim.kaydet(_yedekVerisi(), _yedekAdi, Paylasim.jsonMime);
                  }
                },
              ),
            ),
            Divider(indent: 56, color: renk.outlineVariant),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Yedeği telefona kaydet'),
              onTap: () async {
                final ok = await Paylasim.kaydet(_yedekVerisi(), _yedekAdi, Paylasim.jsonMime);
                if (ok && context.mounted) _mesaj(context, 'Yedek kaydedildi');
              },
            ),
            Divider(indent: 56, color: renk.outlineVariant),
            ListTile(
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('Yedekten geri yükle'),
              subtitle: const Text('Daha önce aldığınız .json dosyasını seçin'),
              onTap: () => _geriYukle(context),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text(
            Bulut.oturum.value != null
                ? 'Kayıtlarınız internet olduğunda hesabınıza da gönderilir. Yine de ayda bir '
                    'yedeği kendinize göndermeniz önerilir.'
                : 'Kayıtlarınız yalnızca bu telefonda durur. Telefon değiştirmeden veya uygulamayı '
                    'silmeden önce mutlaka yedek alın.',
            style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: renk.error),
            title: Text('Tüm verileri sil', style: TextStyle(color: renk.error)),
            onTap: () => _tumunuSil(context),
          ),
        ),
      ],
    );
  }
}
