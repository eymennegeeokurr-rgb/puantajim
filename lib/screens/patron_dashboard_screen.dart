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
import 'gun_duzenle_sayfasi.dart';
import 'patron_personel_sayfasi.dart';

typedef IsciVerisi = ({VeriPaketi veri, int zaman});

const _turuncu = Color(0xFFEF6C00);

/// PATRON MODU ana ekranı — üç sekme:
///   Yoklama : seçilen gün için ekip listesi, tek dokunuşla Geldi / Gelmedi
///   Hakediş : ay toplamı ve kişi kişi ödenecek tutar (patron puantajına göre)
///   Ekip    : personel ekleme, onay bekleyenler
///
/// İşçilerin kendi puantajı salt okunur; hakedişi patronun girdiği günler belirler.
class PatronDashboardScreen extends StatefulWidget {
  const PatronDashboardScreen({super.key});

  @override
  State<PatronDashboardScreen> createState() => _PatronDashboardScreenState();
}

class _PatronDashboardScreenState extends State<PatronDashboardScreen>
    with WidgetsBindingObserver {
  final _patron = PatronDepo.instance;
  final _seciliAy = Depo.instance.seciliAy;

  final Map<String, IsciVerisi?> _veriler = {};
  final Set<String> _yukleniyor = {};
  late final Stream<List<Istek>> _akis = Bulut.gidenIstekler();

  int _sekme = 0;
  DateTime _gun = Bicim.sadeceGun(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _seciliAy.addListener(_ayDegisti);
    _patron.ayHazirla(_gun);
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

  void _ayDegisti() => _patron.ayHazirla(_seciliAy.value);

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
    await _patron.yenile(_gun);
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

  GunKaydi? _isciGunu(String uid, DateTime t) {
    final v = _veriler[uid];
    if (v == null) return null;
    final a = Bicim.anahtar(t);
    for (final k in v.veri.gunler) {
      if (k.tarih == a) return k;
    }
    return null;
  }

  bool _gunFarkli(String uid, DateTime t) {
    if (t.isAfter(Bicim.sadeceGun(DateTime.now()))) return false;
    final u = PuantajHesaplamaEngine.karsilastir(_patron.gun(uid, t), _isciGunu(uid, t));
    return u == Uyusmazlik.farkli || u == Uyusmazlik.patronGirmedi;
  }

  int _ayFarkSayisi(String uid, DateTime ay) {
    final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
    var n = 0;
    for (var g = 1; g <= gunSayisi; g++) {
      if (_gunFarkli(uid, DateTime(ay.year, ay.month, g))) n++;
    }
    return n;
  }

  // ---------------------------------------------------------------------------
  // Yoklama işlemleri
  // ---------------------------------------------------------------------------

  void _gunDegistir(DateTime t) {
    final yeni = Bicim.sadeceGun(t);
    if (yeni.isAfter(Bicim.sadeceGun(DateTime.now()))) return;
    setState(() => _gun = yeni);
    _patron.ayHazirla(yeni);
  }

  Future<void> _gunSec() async {
    final bugun = Bicim.sadeceGun(DateTime.now());
    final secim = await showDatePicker(
      context: context,
      initialDate: _gun,
      firstDate: DateTime(bugun.year - 1, 1, 1),
      lastDate: bugun,
      helpText: 'Yoklama günü',
    );
    if (secim != null) _gunDegistir(secim);
  }

  Future<void> _hizliKaydet(String uid, GunDurumu d) async {
    final mevcut = _patron.gun(uid, _gun);
    if (mevcut?.durum == d) return;
    final GunKaydi yeni;
    if (mevcut != null && d.mesaiGirilebilir) {
      yeni = mevcut.copyWith(durum: d); // saat, mesai, not korunur
    } else {
      yeni = GunKaydi(
        tarih: Bicim.anahtar(_gun),
        durum: d,
        not: mevcut?.not,
        pazarUcretiVer: mevcut?.pazarUcretiVer ?? false,
      );
    }
    await _patron.gunKaydet(uid, yeni);
  }

  Future<void> _detayliGir(Istek i) async {
    final ozet = _ozet(i.calisanUid, DateTime(_gun.year, _gun.month));
    await gunPaneliAc(
      context,
      tarih: _gun,
      mevcut: _patron.gun(i.calisanUid, _gun),
      isciKaydi: _isciGunu(i.calisanUid, _gun),
      profil: _veriler[i.calisanUid]?.veri.profil,
      hafta: ozet?.haftalar[_gun.day],
      patronModu: true,
      kimin: i.calisanAd,
      kaydet: (k) => _patron.gunKaydet(i.calisanUid, k),
      sil: () => _patron.gunSil(i.calisanUid, Bicim.anahtar(_gun)),
    );
  }

  Future<void> _hepsiGeldi(List<Istek> onaylilar) async {
    final gun = _gun;
    final bos = onaylilar
        .where((i) => _patron.gun(i.calisanUid, gun) == null)
        .map((i) => i.calisanUid)
        .toList();
    if (bos.isEmpty) return;
    final yazilan = await _patron.topluGeldi(bos, gun);
    if (!mounted) return;
    _mesaj(
      '${yazilan.length} kişi "Geldi" işaretlendi',
      aksiyon: SnackBarAction(label: 'Geri al', onPressed: () => _patron.topluSil(yazilan, gun)),
    );
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
  // Ekip işlemleri
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
          content: Text('${Bulut.kodDuzelt(kod)} kodlu kişiye ekibinize katılma isteği gönderilsin mi?\n\n'
              'Kişi kendi telefonunda onaylayınca ekibinizde görünür.'),
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
        title: Text('${i.calisanAd} ekipten çıkarılsın mı?'),
        content: const Text('Bu kişinin puantajını artık göremezsiniz. Girdiğiniz yoklama '
            'kayıtları silinmez. Tekrar eklemek için kodu yeniden girmeniz ve onay almanız gerekir.'),
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
    return StreamBuilder<List<Istek>>(
      stream: _akis,
      builder: (context, snap) {
        final liste = snap.data ?? const <Istek>[];
        final onaylilar = liste.where((i) => i.onaylandi).toList()
          ..sort((a, b) => a.calisanAd.toLowerCase().compareTo(b.calisanAd.toLowerCase()));
        for (final i in onaylilar) {
          _yukle(i.calisanUid);
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(const ['Yoklama', 'Hakediş', 'Ekibim'][_sekme]),
                ValueListenableBuilder<String>(
                  valueListenable: _patron.durum,
                  builder: (_, d, __) => Text(
                    d.isEmpty ? 'Patron modu' : 'Patron modu • $d',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const AyarlarSayfasi()));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'bireysel', child: Text('Bireysel moda geç')),
                  PopupMenuItem(value: 'ayarlar', child: Text('Profil ve Ayarlar')),
                ],
              ),
            ],
          ),
          body: ListenableBuilder(
            listenable: Listenable.merge([_patron, _seciliAy]),
            builder: (context, _) {
              final hata = snap.hasError
                  ? Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const ListTile(
                        leading: Icon(Icons.cloud_off),
                        title: Text('Ekip listesi alınamadı'),
                        subtitle: Text('İnternet bağlantınızı kontrol edin.'),
                      ),
                    )
                  : null;
              final yukleniyor = snap.connectionState == ConnectionState.waiting && !snap.hasData;
              return RefreshIndicator(
                onRefresh: () => _hepsiniYenile(onaylilar),
                child: switch (_sekme) {
                  0 => _yoklamaSekmesi(onaylilar, hata, yukleniyor),
                  1 => _hakedisSekmesi(onaylilar, hata),
                  _ => _ekipSekmesi(liste, hata),
                },
              );
            },
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _sekme,
            onDestinationSelected: (i) => setState(() => _sekme = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Yoklama',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Hakediş',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Ekip',
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // YOKLAMA
  // ===========================================================================

  Widget _yoklamaSekmesi(List<Istek> onaylilar, Widget? hata, bool yukleniyor) {
    final renk = Theme.of(context).colorScheme;
    final bugun = Bicim.sadeceGun(DateTime.now());
    final bugunMu = _gun == bugun;
    var geldi = 0, gelmedi = 0, bos = 0;
    for (final i in onaylilar) {
      final k = _patron.gun(i.calisanUid, _gun);
      if (k == null) {
        bos++;
      } else if (k.durum == GunDurumu.geldi || k.durum == GunDurumu.yarimGun) {
        geldi++;
      } else {
        gelmedi++;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ---- Gün seçici
        Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          decoration: BoxDecoration(
            color: renk.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            IconButton(
              tooltip: 'Önceki gün',
              icon: const Icon(Icons.chevron_left),
              color: renk.onPrimaryContainer,
              onPressed: () => _gunDegistir(_gun.subtract(const Duration(days: 1))),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _gunSec,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [
                    Text(bugunMu ? 'Bugün' : Bicim.gunAdi(_gun),
                        style: TextStyle(fontSize: 12, color: renk.onPrimaryContainer)),
                    Text(Bicim.gunAy(_gun),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: renk.onPrimaryContainer)),
                  ]),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sonraki gün',
              icon: const Icon(Icons.chevron_right),
              color: renk.onPrimaryContainer,
              onPressed: bugunMu ? null : () => _gunDegistir(_gun.add(const Duration(days: 1))),
            ),
          ]),
        ),
        if (hata != null) hata,
        if (yukleniyor)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!yukleniyor && onaylilar.isEmpty)
          _bosDurum(
            Icons.groups_outlined,
            'Ekibinizde henüz kimse yok',
            'Ekip sekmesinden elemanlarınızın kodunu girerek ekleyin.',
            buton: FilledButton.icon(
              onPressed: () => setState(() => _sekme = 2),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Ekip sekmesine git'),
            ),
          ),

        if (onaylilar.isNotEmpty) ...[
          // ---- Hepsi geldi + sayaç
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: FilledButton.icon(
              onPressed: bos == 0 ? null : () => _hepsiGeldi(onaylilar),
              icon: const Icon(Icons.done_all),
              label: Text(bos == 0 ? 'Herkes girildi' : 'Hepsi geldi ($bos kişi)'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
            child: Text(
              'Geldi $geldi  •  Gelmedi/izinli $gelmedi  •  Girilmedi $bos',
              style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
            ),
          ),
          for (final i in onaylilar) _yoklamaSatiri(i, renk),
        ],
      ],
    );
  }

  Widget _yoklamaSatiri(Istek i, ColorScheme renk) {
    final k = _patron.gun(i.calisanUid, _gun);
    final farkli = _gunFarkli(i.calisanUid, _gun);
    final isci = _isciGunu(i.calisanUid, _gun);
    final pazar = _gun.weekday == DateTime.sunday;

    String durumYazisi() {
      if (k == null) return 'Girilmedi';
      final e = pazar && k.durum == GunDurumu.geldi ? 'Pazar çalıştı' : k.durum.etiket;
      return k.mesaiSaat > 0 ? '$e • +${Bicim.sayi(k.mesaiSaat)} sa' : e;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
        child: LayoutBuilder(builder: (context, c) {
          final dar = c.maxWidth < 380;
          return Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _detayAc(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    _avatar(i.calisanAd, renk, farkli: farkli),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.calisanAd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(durumYazisi(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: k == null ? renk.outline : k.durum.renk)),
                          if (farkli && isci != null)
                            Text('İşçi: ${isci.durum.etiket}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: _turuncu)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            _durumDugmesi(i.calisanUid, GunDurumu.geldi, k, dar),
            const SizedBox(width: 4),
            _durumDugmesi(i.calisanUid, GunDurumu.gelmedi, k, dar),
            IconButton(
              tooltip: 'Diğer (izin, rapor, mesai...)',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _detayliGir(i),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _durumDugmesi(String uid, GunDurumu d, GunKaydi? k, bool dar) {
    final secili = k?.durum == d;
    final renk = Theme.of(context).colorScheme;
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final ikon = d == GunDurumu.geldi ? Icons.check : Icons.close;
    final yazi = d == GunDurumu.geldi ? 'Geldi' : 'Gelmedi';
    final zemin = secili ? d.renk : d.pastel(koyu: koyu, zemin: renk.surface);
    final on = secili ? Colors.white : d.renk;
    return Tooltip(
      message: yazi,
      child: Material(
        color: zemin,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _hizliKaydet(uid, d),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dar ? 10 : 12, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ikon, size: 18, color: on),
              if (!dar) ...[
                const SizedBox(width: 4),
                Text(yazi,
                    style: TextStyle(color: on, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HAKEDİŞ
  // ===========================================================================

  Widget _hakedisSekmesi(List<Istek> onaylilar, Widget? hata) {
    final renk = Theme.of(context).colorScheme;
    final ay = _seciliAy.value;
    double toplam = 0, banka = 0, elden = 0;
    final ozetler = <String, AylikOzet?>{};
    for (final i in onaylilar) {
      final o = _ozet(i.calisanUid, ay);
      ozetler[i.calisanUid] = o;
      if (o != null) {
        toplam += o.net;
        banka += o.bankaVar ? o.bankaHakedis : 0;
        elden += o.elden;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const AyGezgini(),
        if (hata != null) hata,
        if (onaylilar.isEmpty)
          _bosDurum(Icons.receipt_long_outlined, 'Hakediş yok',
              'Ekibinize personel ekleyip yoklama girdikçe burada görünür.')
        else ...[
          Card(
            color: renk.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('${Bicim.ay(ay)} toplam ödenecek',
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
          for (final i in onaylilar) _hakedisSatiri(i, ozetler[i.calisanUid], ay, renk),
        ],
      ],
    );
  }

  Widget _hakedisSatiri(Istek i, AylikOzet? o, DateTime ay, ColorScheme renk) {
    final yuklendi = _veriler.containsKey(i.calisanUid);
    final fark = _ayFarkSayisi(i.calisanUid, ay);
    final String alt;
    if (!yuklendi) {
      alt = 'Yükleniyor...';
    } else if (o == null) {
      alt = 'Maaş bilgisi yok';
    } else {
      alt = [
        '${Bicim.sayi(o.odenenGun)}/30 gün',
        if (o.mesaiSaat > 0) '${Bicim.sayi(o.mesaiSaat)} sa mesai',
        if (o.kesilenPazar > 0) '${o.kesilenPazar} pazar kesik',
      ].join(' • ');
    }
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        leading: _avatar(i.calisanAd, renk, farkli: fark > 0),
        title: Text(i.calisanAd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          fark > 0 ? '$alt\n$fark gün işçinin kaydıyla farklı' : alt,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: fark > 0,
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
      ),
    );
  }

  // ===========================================================================
  // EKİP
  // ===========================================================================

  Widget _ekipSekmesi(List<Istek> liste, Widget? hata) {
    final renk = Theme.of(context).colorScheme;
    final onaylilar = liste.where((i) => i.onaylandi).toList();
    final bekleyen = liste.where((i) => i.bekliyor).toList();
    final reddeden = liste.where((i) => i.reddedildi).toList();

    Widget baslik(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          child: Text(t, style: TextStyle(color: renk.primary, fontWeight: FontWeight.w700)),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: FilledButton.icon(
            onPressed: _personelEkle,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Personel Ekle'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
          child: Text(
            'Elemanınızdan uygulamasındaki Profil sekmesinde yazan kullanıcı kodunu isteyin. '
            'Kodu girince elemana istek gider; o onaylayınca ekibinize katılır.',
            style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant),
          ),
        ),
        if (hata != null) hata,
        if (onaylilar.isNotEmpty) baslik('Ekibim (${onaylilar.length})'),
        for (final i in onaylilar)
          Card(
            child: ListTile(
              leading: _avatar(i.calisanAd, renk),
              title: Text(i.calisanAd, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_veriler[i.calisanUid]?.veri.profil?.gorev ?? ''),
              trailing: PopupMenuButton<String>(
                onSelected: (s) => s == 'cikar' ? _listedenCikar(i) : _detayAc(i),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'ac', child: Text('Puantajını aç')),
                  PopupMenuItem(value: 'cikar', child: Text('Ekipten çıkar')),
                ],
              ),
              onTap: () => _detayAc(i),
            ),
          ),
        if (bekleyen.isNotEmpty) baslik('Onay bekleyenler'),
        for (final i in bekleyen)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.hourglass_top)),
              title: Text(i.calisanAd),
              subtitle: Text(
                  'İstek: ${Bicim.kisaTarih(DateTime.fromMillisecondsSinceEpoch(i.tarih))} • henüz onaylamadı'),
              trailing: IconButton(
                tooltip: 'İsteği geri çek',
                icon: const Icon(Icons.close),
                onPressed: () => _listedenCikar(i),
              ),
            ),
          ),
        if (reddeden.isNotEmpty) baslik('Reddedenler'),
        for (final i in reddeden)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: renk.errorContainer,
                  child: Icon(Icons.block, color: renk.onErrorContainer)),
              title: Text(i.calisanAd),
              subtitle: const Text('İsteği reddetti'),
              trailing: PopupMenuButton<String>(
                onSelected: (s) async {
                  if (s == 'tekrar') {
                    try {
                      await Bulut.istekGonder(calisanUid: i.calisanUid, calisanAd: i.calisanAd);
                    } catch (e) {
                      if (mounted) _mesaj(e is BulutHatasi ? e.mesaj : 'Hata: $e');
                    }
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
    );
  }

  // ===========================================================================

  Widget _avatar(String ad, ColorScheme renk, {bool farkli = false}) {
    final basHarf = ad
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((s) => s.isEmpty ? '' : s[0])
        .join()
        .toUpperCase();
    return Badge(
      isLabelVisible: farkli,
      backgroundColor: _turuncu,
      smallSize: 10,
      child: CircleAvatar(
        backgroundColor: renk.secondaryContainer,
        child: Text(basHarf, style: TextStyle(color: renk.onSecondaryContainer)),
      ),
    );
  }

  Widget _bosDurum(IconData ikon, String baslik, String aciklama, {Widget? buton}) {
    final renk = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(children: [
        Icon(ikon, size: 60, color: renk.outline),
        const SizedBox(height: 12),
        Text(baslik, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(aciklama,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
        if (buton != null) ...[const SizedBox(height: 14), buton],
      ]),
    );
  }
}
