import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../models/veri_paketi.dart';
import '../services/bicim.dart';
import '../services/bulut.dart';
import '../services/hesaplama.dart';
import '../widgets/ay_gezgini.dart';
import 'personel_detay_sayfasi.dart';

/// YÖNETİCİ PANELİ: kodla eklenen ve onay veren elemanların listesi.
/// Sadece görüntüleme - elemanın kayıtları buradan değiştirilemez.
class EkipSayfasi extends StatefulWidget {
  const EkipSayfasi({super.key});

  @override
  State<EkipSayfasi> createState() => _EkipSayfasiState();
}

class _EkipSayfasiState extends State<EkipSayfasi> {
  /// uid -> yüklenen veri (null: veri yok / yüklenemedi)
  final Map<String, ({VeriPaketi veri, int zaman})?> _veriler = {};
  final Set<String> _yukleniyor = {};

  /// Akış bir kere oluşturulur (her yeniden çizimde sorgu tekrar başlamasın)
  late final Stream<List<Istek>> _akis = Bulut.gidenIstekler();

  Future<void> _yukle(String uid, {bool zorla = false}) async {
    if (_yukleniyor.contains(uid) || (!zorla && _veriler.containsKey(uid))) return;
    _yukleniyor.add(uid);
    try {
      final v = await Bulut.personelVerisi(uid);
      _veriler[uid] = v;
    } catch (_) {
      _veriler[uid] = null;
    } finally {
      _yukleniyor.remove(uid);
      if (mounted) setState(() {});
    }
  }

  Future<void> _hepsiniYenile(List<Istek> onaylilar) async {
    for (final i in onaylilar) {
      await _yukle(i.calisanUid, zorla: true);
    }
  }

  AylikOzet? _ozet(VeriPaketi v, DateTime ay) {
    final p = v.profil;
    if (p == null) return null;
    return Hesaplama.hesapla(
      profil: p,
      ay: ay,
      kayitlar: v.ayKayitlari(ay),
      hareketler: v.ayHareketleri(ay),
      oncekiAyKayitlari: v.ayKayitlari(DateTime(ay.year, ay.month - 1)),
    );
  }

  // ---------------------------------------------------------------------------
  // Personel ekleme (kodla)
  // ---------------------------------------------------------------------------

  Future<void> _personelEkle() async {
    final ctrl = TextEditingController();
    final kod = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_add_alt_1),
        title: const Text('Personel Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Elemanın uygulamasında Profil sekmesinde yazan kullanıcı kodunu girin.'),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı kodu',
                hintText: 'PJ-XXXX-XXXX',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Ara')),
        ],
      ),
    );
    if (kod == null || kod.trim().isEmpty || !mounted) return;

    try {
      final kisi = await Bulut.kodBul(kod);
      if (!mounted) return;
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.person),
          title: Text(kisi.adSoyad.isEmpty ? 'İsimsiz kullanıcı' : kisi.adSoyad),
          content: Text(
              '${Bulut.kodDuzelt(kod)} kodlu kişiye takip isteği gönderilsin mi?\n\n'
              'Kişi uygulamasında isteği onaylayınca puantajını görebileceksiniz.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('İstek Gönder')),
          ],
        ),
      );
      if (onay != true) return;
      await Bulut.istekGonder(calisanUid: kisi.uid, calisanAd: kisi.adSoyad);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${kisi.adSoyad} için istek gönderildi, onay bekleniyor')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e is BulutHatasi ? e.mesaj : 'Hata: $e')));
      }
    }
  }

  Future<void> _listedenCikar(Istek i) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${i.calisanAd} listeden çıkarılsın mı?'),
        content: const Text(
            'Bu kişinin verilerini artık göremezsiniz. Tekrar eklemek için kodu yeniden girmeniz ve onay almanız gerekir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkar')),
        ],
      ),
    );
    if (onay == true) await Bulut.istekSil(i);
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return StreamBuilder<List<Istek>>(
      stream: _akis,
      builder: (context, snap) {
        final liste = snap.data ?? const <Istek>[];
        final onaylilar = liste.where((i) => i.onaylandi).toList();
        final bekleyen = liste.where((i) => i.bekliyor).toList();
        final reddeden = liste.where((i) => i.reddedildi).toList();
        for (final i in onaylilar) {
          _yukle(i.calisanUid);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Ekibim (Yönetici)'),
            actions: [
              IconButton(
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh),
                onPressed: () => _hepsiniYenile(onaylilar),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _personelEkle,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Personel Ekle'),
          ),
          body: ValueListenableBuilder<DateTime>(
            valueListenable: Depo.instance.seciliAy,
            builder: (context, ay, _) {
              // Ay toplamları
              double toplam = 0, banka = 0, elden = 0;
              for (final i in onaylilar) {
                final v = _veriler[i.calisanUid];
                final o = v == null ? null : _ozet(v.veri, ay);
                if (o != null) {
                  toplam += o.net;
                  banka += o.bankaVar ? o.bankaHakedis : 0;
                  elden += o.elden;
                }
              }

              return RefreshIndicator(
                onRefresh: () => _hepsiniYenile(onaylilar),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    const AyGezgini(),
                    if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (snap.hasError)
                      Card(
                        color: renk.errorContainer,
                        child: ListTile(
                          leading: const Icon(Icons.cloud_off),
                          title: const Text('Liste alınamadı'),
                          subtitle: Text('İnternet bağlantınızı kontrol edin.\n${snap.error}'),
                        ),
                      ),

                    // ---- Toplam kartı
                    if (onaylilar.isNotEmpty)
                      Card(
                        color: renk.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            Text('${onaylilar.length} personel • ${Bicim.ay(ay)} toplam alacak',
                                style: TextStyle(color: renk.onPrimaryContainer)),
                            const SizedBox(height: 4),
                            Text(Bicim.para(toplam),
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: renk.onPrimaryContainer)),
                            Text('Banka ${Bicim.para(banka)}  •  Elden ${Bicim.para(elden)}',
                                style: TextStyle(fontSize: 12.5, color: renk.onPrimaryContainer)),
                          ]),
                        ),
                      ),

                    if (liste.isEmpty && snap.hasData)
                      Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(children: [
                          Icon(Icons.groups_outlined, size: 60, color: renk.outline),
                          const SizedBox(height: 12),
                          const Text('Henüz personel eklenmedi', textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          Text(
                            'Elemanlarınızdan Profil sekmesindeki kullanıcı kodunu isteyin, '
                            '"Personel Ekle" ile girin. Eleman onaylayınca burada görünür.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
                          ),
                        ]),
                      ),

                    // ---- Onaylılar
                    for (final i in onaylilar) _personelKarti(i, ay, renk),

                    // ---- Bekleyenler
                    if (bekleyen.isNotEmpty) _baslik('Onay bekleyenler', renk),
                    for (final i in bekleyen)
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
                          title: Text(i.calisanAd),
                          subtitle: Text('İstek: ${Bicim.kisaTarih(DateTime.fromMillisecondsSinceEpoch(i.tarih))} • eleman henüz onaylamadı'),
                          trailing: IconButton(
                            tooltip: 'İsteği geri çek',
                            icon: const Icon(Icons.close),
                            onPressed: () => _listedenCikar(i),
                          ),
                        ),
                      ),

                    // ---- Reddedenler
                    if (reddeden.isNotEmpty) _baslik('Reddedenler', renk),
                    for (final i in reddeden)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundColor: renk.errorContainer,
                              child: Icon(Icons.block, color: renk.onErrorContainer)),
                          title: Text(i.calisanAd),
                          subtitle: const Text('Takip isteğini reddetti'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (s) async {
                              if (s == 'tekrar') {
                                await Bulut.istekGonder(
                                    calisanUid: i.calisanUid, calisanAd: i.calisanAd);
                              } else {
                                await _listedenCikar(i);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'tekrar', child: Text('Tekrar iste')),
                              PopupMenuItem(value: 'sil', child: Text('Listeden çıkar')),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _baslik(String t, ColorScheme renk) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t, style: TextStyle(color: renk.primary, fontWeight: FontWeight.w700)),
      );

  Widget _personelKarti(Istek i, DateTime ay, ColorScheme renk) {
    final yuklendi = _veriler.containsKey(i.calisanUid);
    final v = _veriler[i.calisanUid];
    final o = v == null ? null : _ozet(v.veri, ay);
    final gorev = v?.veri.profil?.gorev ?? '';

    String altYazi;
    if (!yuklendi) {
      altYazi = 'Yükleniyor...';
    } else if (v == null) {
      altYazi = 'Henüz veri göndermemiş';
    } else if (o == null) {
      altYazi = 'Profil bilgisi girilmemiş';
    } else {
      altYazi = '${Bicim.sayi(o.odenenGun)} gün • ${Bicim.sayi(o.mesaiSaat)} sa mesai'
          '${o.isaretsizGun > 0 ? ' • ${o.isaretsizGun} gün girilmemiş' : ''}';
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        leading: CircleAvatar(
          backgroundColor: renk.secondaryContainer,
          child: Text(
            i.calisanAd.trim().split(RegExp(r'\s+')).take(2).map((s) => s.isEmpty ? '' : s[0]).join().toUpperCase(),
            style: TextStyle(color: renk.onSecondaryContainer),
          ),
        ),
        title: Text(i.calisanAd, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([if (gorev.isNotEmpty) gorev, altYazi].join('\n')),
        isThreeLine: gorev.isNotEmpty,
        trailing: o == null
            ? const Icon(Icons.chevron_right)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Bicim.para(o.net),
                      style: TextStyle(fontWeight: FontWeight.w800, color: renk.primary)),
                  if (o.bankaVar)
                    Text('Elden ${Bicim.para(o.elden)}',
                        style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
                ],
              ),
        onTap: v == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PersonelDetaySayfasi(
                  ad: i.calisanAd,
                  uid: i.calisanUid,
                  ilkVeri: v.veri,
                  ilkZaman: v.zaman,
                ),
              )),
        onLongPress: () => _listedenCikar(i),
      ),
    );
  }
}
