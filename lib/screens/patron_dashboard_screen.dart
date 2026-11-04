import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../data/patron_depo.dart';
import '../models/gun_kaydi.dart';
import '../models/veri_paketi.dart';
import '../services/app_mode_controller.dart';
import '../services/bicim.dart';
import '../services/bulut.dart';
import '../services/guncelleme.dart';
import '../services/hesaplama.dart';
import '../services/puantaj_hesaplama_engine.dart';
import '../widgets/ay_gezgini.dart';
import 'ayarlar_sayfasi.dart';
import 'patron_personel_sayfasi.dart';

typedef IsciVerisi = ({VeriPaketi veri, int zaman});

/// PATRON PANELİ: ekip listesi, "Tüm Ekibi Geldi İşaretle", uyuşmazlıklar.
///
/// İşçilerin kendi puantajı (kodla eşleşen, onay veren) sadece okunur.
/// Hakedişi belirleyen, patronun burada girdiği "Patron Puantajı"dır.
class PatronDashboardScreen extends StatefulWidget {
  const PatronDashboardScreen({super.key});

  @override
  State<PatronDashboardScreen> createState() => _PatronDashboardScreenState();
}

class _PatronDashboardScreenState extends State<PatronDashboardScreen>
    with WidgetsBindingObserver {
  final _patron = PatronDepo.instance;
  final _seciliAy = Depo.instance.seciliAy;

  /// uid -> işçinin buluttaki verisi (null: veri yok / yüklenemedi)
  final Map<String, IsciVerisi?> _veriler = {};
  final Set<String> _yukleniyor = {};
  late final Stream<List<Istek>> _akis = Bulut.gidenIstekler();

  /// Toplu giriş yapılacak gün
  DateTime _topluGun = Bicim.sadeceGun(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _seciliAy.addListener(_ayDegisti);
    _patron.ayHazirla(_seciliAy.value);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final yeni = await Guncelleme.kontrolEt();
      if (yeni != null && mounted) await Guncelleme.pencereGoster(context, yeni);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _seciliAy.removeListener(_ayDegisti);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _patron.bekleyenleriGonder();
      Bulut.senkronla();
    }
  }

  void _ayDegisti() {
    final ay = _seciliAy.value;
    _patron.ayHazirla(ay);
    // Toplu giriş günü seçili ayın içinde kalsın
    if (_topluGun.year != ay.year || _topluGun.month != ay.month) {
      final bugun = Bicim.sadeceGun(DateTime.now());
      setState(() => _topluGun = (bugun.year == ay.year && bugun.month == ay.month)
          ? bugun
          : DateTime(ay.year, ay.month, 1));
    }
  }

  Future<void> _yukle(String uid, {bool zorla = false}) async {
    if (_yukleniyor.contains(uid) || (!zorla && _veriler.containsKey(uid))) return;
    _yukleniyor.add(uid);
    try {
      _veriler[uid] = await Bulut.personelVerisi(uid);
    } catch (_) {
      _veriler[uid] = null;
    } finally {
      _yukleniyor.remove(uid);
      if (mounted) setState(() {});
    }
  }

  Future<void> _hepsiniYenile(List<Istek> onaylilar) async {
    await _patron.yenile(_seciliAy.value);
    for (final i in onaylilar) {
      await _yukle(i.calisanUid, zorla: true);
    }
  }

  void _mesaj(String m, {SnackBarAction? aksiyon}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), action: aksiyon));
  }

  // ---------------------------------------------------------------------------
  // Hesaplar
  // ---------------------------------------------------------------------------

  AylikOzet? _ozet(String uid, DateTime ay) {
    final v = _veriler[uid];
    final p = v?.veri.profil;
    if (v == null || p == null) return null;
    return Hesaplama.hesapla(
      profil: p,
      ay: ay,
      kayitlar: _patron.isciKayitlari(uid, ay),
      hareketler: v.veri.ayHareketleri(ay),
      oncekiAyKayitlari: _patron.isciKayitlari(uid, DateTime(ay.year, ay.month - 1)),
    );
  }

  /// Bugüne kadarki uyuşmayan gün sayısı (farklı + patronun girmediği)
  int _uyusmazlik(String uid, DateTime ay) {
    final v = _veriler[uid];
    if (v == null) return 0;
    final isci = {for (final k in v.veri.ayKayitlari(ay)) k.tarih: k};
    final patron = _patron.isciAyi(uid, ay);
    final bugun = Bicim.sadeceGun(DateTime.now());
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    var n = 0;
    for (var g = 1; g <= gunSayisi; g++) {
      final t = DateTime(ay.year, ay.month, g);
      if (t.isAfter(bugun)) break;
      final a = Bicim.anahtar(t);
      final u = PuantajHesaplamaEngine.karsilastir(patron[a], isci[a]);
      if (u == Uyusmazlik.farkli || u == Uyusmazlik.patronGirmedi) n++;
    }
    return n;
  }

  // ---------------------------------------------------------------------------
  // Toplu giriş
  // ---------------------------------------------------------------------------

  Future<void> _topluGunSec() async {
    final ay = _seciliAy.value;
    final son = DateTime(ay.year, ay.month + 1, 0);
    final bugun = Bicim.sadeceGun(DateTime.now());
    final secim = await showDatePicker(
      context: context,
      initialDate: _topluGun,
      firstDate: DateTime(ay.year, ay.month, 1),
      lastDate: son.isAfter(bugun) && !bugun.isBefore(DateTime(ay.year, ay.month, 1))
          ? bugun
          : son,
      helpText: 'Toplu giriş günü',
    );
    if (secim != null) setState(() => _topluGun = secim);
  }

  Future<void> _tumEkibiGeldi(List<Istek> onaylilar) async {
    final gun = _topluGun;
    final bos = onaylilar.where((i) => _patron.gun(i.calisanUid, gun) == null).toList();
    if (onaylilar.isEmpty) {
      _mesaj('Önce ekibinize personel ekleyin');
      return;
    }
    if (bos.isEmpty) {
      _mesaj('${Bicim.gunAy(gun)} için tüm ekibin kaydı zaten girilmiş');
      return;
    }
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.groups),
        title: const Text('Tüm ekip "Geldi" işaretlensin mi?'),
        content: Text(
          '${Bicim.gunAy(gun)}: ${bos.length} kişiye "Geldi" yazılacak.'
          '${bos.length < onaylilar.length ? '\n${onaylilar.length - bos.length} kişinin kaydı zaten var, değiştirilmeyecek.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İşaretle')),
        ],
      ),
    );
    if (onay != true) return;
    final yazilan = await _patron.topluGeldi(bos.map((i) => i.calisanUid), gun);
    if (!mounted) return;
    _mesaj(
      '${yazilan.length} kişi "Geldi" işaretlendi',
      aksiyon: SnackBarAction(
        label: 'Geri al',
        onPressed: () => _patron.topluSil(yazilan, gun),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Personel ekleme / çıkarma
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
            const Text('Elemanın uygulamasında Profil sekmesinde yazan kullanıcı kodunu girin.'),
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
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Ara')),
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
          content: Text('${Bulut.kodDuzelt(kod)} kodlu kişiye takip isteği gönderilsin mi?\n\n'
              'Kişi uygulamasında isteği onaylayınca puantajını görebileceksiniz.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İstek Gönder')),
          ],
        ),
      );
      if (onay != true) return;
      await Bulut.istekGonder(calisanUid: kisi.uid, calisanAd: kisi.adSoyad);
      if (mounted) _mesaj('${kisi.adSoyad} için istek gönderildi, onay bekleniyor');
    } catch (e) {
      if (mounted) _mesaj(e is BulutHatasi ? e.mesaj : 'Hata: $e');
    }
  }

  Future<void> _listedenCikar(Istek i) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${i.calisanAd} listeden çıkarılsın mı?'),
        content: const Text('Bu kişinin verilerini artık göremezsiniz. Girdiğiniz patron '
            'puantajı silinmez. Tekrar eklemek için kodu yeniden girmeniz ve onay almanız gerekir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkar')),
        ],
      ),
    );
    if (onay == true) await Bulut.istekSil(i);
  }

  void _detayAc(Istek i) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PatronPersonelSayfasi(
        ad: i.calisanAd,
        uid: i.calisanUid,
        ilkVeri: _veriler[i.calisanUid],
        veriYenilendi: (v) => setState(() => _veriler[i.calisanUid] = v),
      ),
    ));
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Patron Paneli'),
                ValueListenableBuilder<String>(
                  valueListenable: _patron.durum,
                  builder: (_, d, __) => Text(
                    d.isEmpty ? (Bulut.oturum.value?.adSoyad ?? '') : d,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh),
                onPressed: () => _hepsiniYenile(onaylilar),
              ),
              PopupMenuButton<String>(
                onSelected: (s) {
                  if (s == 'bireysel') {
                    AppModeController.instance.ayarla(AppMode.bireysel);
                  } else if (s == 'ayarlar') {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AyarlarSayfasi()));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'bireysel',
                    child: ListTile(
                      leading: Icon(Icons.person_outline),
                      title: Text('Bireysel moda geç'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ayarlar',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Profil ve Ayarlar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _personelEkle,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Personel Ekle'),
          ),
          body: ListenableBuilder(
            listenable: Listenable.merge([_patron, _seciliAy]),
            builder: (context, _) {
              final ay = _seciliAy.value;
              double toplam = 0, banka = 0, elden = 0;
              final uyusmazliklar = <(Istek, int)>[];
              for (final i in onaylilar) {
                final o = _ozet(i.calisanUid, ay);
                if (o != null) {
                  toplam += o.net;
                  banka += o.bankaVar ? o.bankaHakedis : 0;
                  elden += o.elden;
                }
                final n = _uyusmazlik(i.calisanUid, ay);
                if (n > 0) uyusmazliklar.add((i, n));
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
                          title: const Text('Ekip listesi alınamadı'),
                          subtitle: Text('İnternet bağlantınızı kontrol edin.\n${snap.error}'),
                        ),
                      ),

                    // ---- Toplam
                    if (onaylilar.isNotEmpty)
                      Card(
                        color: renk.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            Text('${onaylilar.length} personel • ${Bicim.ay(ay)} (patron puantajı)',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: renk.onPrimaryContainer)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(Bicim.para(toplam),
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: renk.onPrimaryContainer)),
                            ),
                            Text('Banka ${Bicim.para(banka)}  •  Elden ${Bicim.para(elden)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: renk.onPrimaryContainer)),
                          ]),
                        ),
                      ),

                    // ---- Toplu giriş
                    if (onaylilar.isNotEmpty) _topluKarti(onaylilar, renk),

                    // ---- Uyuşmazlıklar
                    if (uyusmazliklar.isNotEmpty) _uyusmazlikKarti(uyusmazliklar),

                    if (liste.isEmpty && snap.hasData) _bosEkip(renk),

                    // ---- Ekip
                    if (onaylilar.isNotEmpty) _baslik('Ekibim', renk),
                    for (final i in onaylilar) _personelKarti(i, ay, renk),

                    // ---- Bekleyenler
                    if (bekleyen.isNotEmpty) _baslik('Onay bekleyenler', renk),
                    for (final i in bekleyen)
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
                          title: Text(i.calisanAd),
                          subtitle: Text('İstek: ${Bicim.kisaTarih(DateTime.fromMillisecondsSinceEpoch(i.tarih))} • henüz onaylamadı'),
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

  Widget _topluKarti(List<Istek> onaylilar, ColorScheme renk) {
    final bos = onaylilar.where((i) => _patron.gun(i.calisanUid, _topluGun) == null).length;
    final bugunMu = _topluGun == Bicim.sadeceGun(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.bolt, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Hızlı puantaj',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              TextButton.icon(
                onPressed: _topluGunSec,
                icon: const Icon(Icons.event, size: 18),
                label: Text(bugunMu ? 'Bugün' : Bicim.gunAy(_topluGun),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            Text(
              bos == 0
                  ? 'Bu gün için tüm ekibin kaydı girilmiş.'
                  : '$bos kişinin bu günü henüz girilmemiş.',
              style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: bos == 0 ? null : () => _tumEkibiGeldi(onaylilar),
              icon: const Icon(Icons.done_all),
              label: const Text('Tüm Ekibi Geldi İşaretle'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uyusmazlikKarti(List<(Istek, int)> l) {
    const turuncu = Color(0xFFEF6C00);
    final toplam = l.fold<int>(0, (a, e) => a + e.$2);
    return Card(
      color: turuncu.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: turuncu.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.compare_arrows, color: turuncu),
              title: Text('$toplam gün uyuşmuyor',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'İşçinin girdiği ile sizin puantajınız farklı veya siz henüz girmediniz.'),
            ),
            for (final e in l)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(e.$1.calisanAd, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${e.$2} gün',
                      style: const TextStyle(color: turuncu, fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right),
                ]),
                onTap: () => _detayAc(e.$1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bosEkip(ColorScheme renk) => Padding(
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
      );

  Widget _baslik(String t, ColorScheme renk) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t, style: TextStyle(color: renk.primary, fontWeight: FontWeight.w700)),
      );

  Widget _personelKarti(Istek i, DateTime ay, ColorScheme renk) {
    final yuklendi = _veriler.containsKey(i.calisanUid);
    final v = _veriler[i.calisanUid];
    final o = _ozet(i.calisanUid, ay);
    final gorev = v?.veri.profil?.gorev ?? '';
    final n = _uyusmazlik(i.calisanUid, ay);
    final bugun = _patron.gun(i.calisanUid, Bicim.sadeceGun(DateTime.now()));
    final girilen = _patron.isciAyi(i.calisanUid, ay).length;

    String altYazi;
    if (!yuklendi) {
      altYazi = 'Yükleniyor...';
    } else if (v == null || v.veri.profil == null) {
      altYazi = 'Maaş bilgisi yok • $girilen gün girdiniz';
    } else {
      altYazi = '${Bicim.sayi(o!.odenenGun)} gün • ${Bicim.sayi(o.mesaiSaat)} sa mesai'
          '${o.kesilenPazar > 0 ? ' • ${o.kesilenPazar} pazar kesik' : ''}';
    }
    final basHarf = i.calisanAd
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '' : s[0])
        .join()
        .toUpperCase();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        leading: Badge(
          isLabelVisible: n > 0,
          backgroundColor: const Color(0xFFEF6C00),
          label: Text('$n'),
          child: CircleAvatar(
            backgroundColor: bugun == null
                ? renk.secondaryContainer
                : bugun.durum.pastel(
                    koyu: Theme.of(context).brightness == Brightness.dark,
                    zemin: renk.surface),
            child: bugun == null
                ? Text(basHarf, style: TextStyle(color: renk.onSecondaryContainer))
                : Icon(bugun.durum.ikon, color: bugun.durum.renk),
          ),
        ),
        title: Text(i.calisanAd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([if (gorev.isNotEmpty) gorev, altYazi].join('\n'),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        isThreeLine: gorev.isNotEmpty,
        trailing: o == null
            ? const Icon(Icons.chevron_right)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(Bicim.para(o.net),
                          style: TextStyle(fontWeight: FontWeight.w800, color: renk.primary)),
                    ),
                    if (o.bankaVar)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Elden ${Bicim.para(o.elden)}',
                            style: TextStyle(fontSize: 11, color: renk.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
        onTap: () => _detayAc(i),
        onLongPress: () => _listedenCikar(i),
      ),
    );
  }
}
