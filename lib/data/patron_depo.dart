import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/gun_kaydi.dart';
import '../services/bicim.dart';
import '../services/bulut.dart';
import 'depo.dart';

/// PATRON PUANTAJI: patronun her işçi için girdiği, hakedişi belirleyen günler.
///
/// İşçinin kendi kaydına dokunulmaz (o salt okunur). Patron kayıtları:
///   - telefonda: SharedPreferences, ay ay  ("patronAy_2026-11")
///   - bulutta : kullanicilar/{patronUid}/veri/ekip-2026-11
/// Her ay belgesi:  { "zaman": ms, "isciler": { uid: { tarih: GunKaydi } } }
/// Telefon ve bulut karşılaştırılır, hangisi yeniyse o geçerli olur.
class PatronDepo extends ChangeNotifier {
  PatronDepo._();
  static final PatronDepo instance = PatronDepo._();

  static const _onEk = 'patronAy_';
  static const _bekleyenAnahtar = 'patronBekleyen';

  /// ayKodu -> işçi uid -> tarih -> kayıt
  final Map<String, Map<String, Map<String, GunKaydi>>> _aylar = {};
  final Map<String, int> _zaman = {};
  final Set<String> _buluttanAlinan = {};

  /// Bulutla eşitleme durumu (ekranda küçük yazı)
  final durum = ValueNotifier<String>('');

  static String ayKodu(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}';

  static String _belgeAdi(String kod) => 'ekip-$kod';

  // ---------------------------------------------------------------------------
  // OKUMA
  // ---------------------------------------------------------------------------

  /// Ayı telefondan yükler, sonra (internet varsa) bulutla eşitler.
  /// Hafta hesabı için önceki ay da yüklenir.
  Future<void> ayHazirla(DateTime ay) async {
    final kodlar = {ayKodu(ay), ayKodu(DateTime(ay.year, ay.month - 1))};
    for (final k in kodlar) {
      _yereldenOku(k);
    }
    notifyListeners();
    for (final k in kodlar) {
      await _bulutlaEsitle(k);
    }
  }

  void _yereldenOku(String kod) {
    if (_aylar.containsKey(kod)) return;
    final metin = Depo.instance.prefs.getString('$_onEk$kod');
    if (metin == null) {
      _aylar[kod] = {};
      _zaman[kod] = 0;
      return;
    }
    try {
      final j = jsonDecode(metin) as Map<String, dynamic>;
      _aylar[kod] = _ayristir(j);
      _zaman[kod] = (j['zaman'] as num?)?.toInt() ?? 0;
    } catch (_) {
      _aylar[kod] = {};
      _zaman[kod] = 0;
    }
  }

  static Map<String, Map<String, GunKaydi>> _ayristir(Map<String, dynamic> j) {
    final sonuc = <String, Map<String, GunKaydi>>{};
    final isciler = (j['isciler'] as Map<String, dynamic>?) ?? const {};
    for (final e in isciler.entries) {
      final gunler = <String, GunKaydi>{};
      for (final g in (e.value as Map<String, dynamic>).values) {
        final k = GunKaydi.fromJson(g as Map<String, dynamic>);
        gunler[k.tarih] = k;
      }
      sonuc[e.key] = gunler;
    }
    return sonuc;
  }

  String _metin(String kod) => jsonEncode({
        'zaman': _zaman[kod] ?? 0,
        'isciler': {
          for (final e in (_aylar[kod] ?? const {}).entries)
            e.key: {for (final g in e.value.values) g.tarih: g.toJson()},
        },
      });

  Future<void> _bulutlaEsitle(String kod, {bool zorla = false}) async {
    if (Bulut.benimUid == null) return;
    if (!zorla && _buluttanAlinan.contains(kod) && !_bekliyor(kod)) return;
    try {
      final b = await Bulut.belgeGetir(_belgeAdi(kod));
      final yerel = _zaman[kod] ?? 0;
      if (b != null && b.zaman > yerel) {
        final j = jsonDecode(b.metin) as Map<String, dynamic>;
        _aylar[kod] = _ayristir(j);
        _zaman[kod] = b.zaman;
        await Depo.instance.prefs.setString('$_onEk$kod', b.metin);
        await _bekleyenCikar(kod);
        notifyListeners();
      } else if (yerel > (b?.zaman ?? 0)) {
        await _gonder(kod);
      }
      _buluttanAlinan.add(kod);
      durum.value = 'Eşitlendi';
    } catch (e) {
      durum.value = 'Çevrimdışı - internet gelince gönderilecek';
      debugPrint('Patron puantajı eşitlenemedi: $e');
    }
  }

  /// Ekran yenilenirken (aşağı çekince) bulutu tekrar kontrol et
  Future<void> yenile(DateTime ay) async {
    for (final k in {ayKodu(ay), ayKodu(DateTime(ay.year, ay.month - 1))}) {
      _yereldenOku(k);
      await _bulutlaEsitle(k, zorla: true);
    }
  }

  /// İşçinin o aydaki patron kayıtları (tarih -> kayıt)
  Map<String, GunKaydi> isciAyi(String uid, DateTime ay) {
    final kod = ayKodu(ay);
    _yereldenOku(kod);
    return Map.unmodifiable(_aylar[kod]?[uid] ?? const <String, GunKaydi>{});
  }

  /// Hesap için: o ay ve önceki ayın kayıtları listesi
  List<GunKaydi> isciKayitlari(String uid, DateTime ay) {
    final l = isciAyi(uid, ay).values.toList()
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    return l;
  }

  GunKaydi? gun(String uid, DateTime t) => isciAyi(uid, t)[Bicim.anahtar(t)];

  // ---------------------------------------------------------------------------
  // YAZMA
  // ---------------------------------------------------------------------------

  Map<String, GunKaydi> _yazilabilir(String uid, String kod) {
    _yereldenOku(kod);
    return (_aylar[kod]!.putIfAbsent(uid, () => <String, GunKaydi>{}));
  }

  Future<void> gunKaydet(String uid, GunKaydi k) async {
    final kod = k.tarih.substring(0, 7);
    _yazilabilir(uid, kod)[k.tarih] = k;
    await _degisti({kod});
  }

  Future<void> gunSil(String uid, String tarih) async {
    final kod = tarih.substring(0, 7);
    _yazilabilir(uid, kod).remove(tarih);
    await _degisti({kod});
  }

  /// "Tüm Ekibi Geldi İşaretle": o gün patron kaydı OLMAYAN herkese "Geldi"
  /// yazar. Var olan kayıtlara dokunmaz. Yazılan uid'leri döner (geri almak için).
  Future<List<String>> topluGeldi(Iterable<String> uidler, DateTime gunTarihi) async {
    final tarih = Bicim.anahtar(gunTarihi);
    final kod = tarih.substring(0, 7);
    final yazilan = <String>[];
    for (final uid in uidler) {
      final gunler = _yazilabilir(uid, kod);
      if (gunler.containsKey(tarih)) continue;
      gunler[tarih] = GunKaydi(tarih: tarih, durum: GunDurumu.geldi);
      yazilan.add(uid);
    }
    if (yazilan.isNotEmpty) await _degisti({kod});
    return yazilan;
  }

  /// Toplu işlemi geri al
  Future<void> topluSil(Iterable<String> uidler, DateTime gunTarihi) async {
    final tarih = Bicim.anahtar(gunTarihi);
    final kod = tarih.substring(0, 7);
    for (final uid in uidler) {
      _yazilabilir(uid, kod).remove(tarih);
    }
    await _degisti({kod});
  }

  /// İşçinin kendi kayıtlarını patron puantajına kopyalar (sadece verilen tarihler)
  Future<void> isciKaydiniKabulEt(String uid, Iterable<GunKaydi> isciKayitlari) async {
    final kodlar = <String>{};
    for (final k in isciKayitlari) {
      final kod = k.tarih.substring(0, 7);
      final mevcut = _yazilabilir(uid, kod)[k.tarih];
      // Patronun verdiği pazar inisiyatifi korunur
      _yazilabilir(uid, kod)[k.tarih] =
          k.copyWith(pazarUcretiVer: mevcut?.pazarUcretiVer ?? false);
      kodlar.add(kod);
    }
    if (kodlar.isNotEmpty) await _degisti(kodlar);
  }

  Future<void> _degisti(Set<String> kodlar) async {
    final simdi = DateTime.now().millisecondsSinceEpoch;
    for (final kod in kodlar) {
      _zaman[kod] = simdi;
      await Depo.instance.prefs.setString('$_onEk$kod', _metin(kod));
      await _bekleyenEkle(kod);
    }
    notifyListeners();
    for (final kod in kodlar) {
      unawaited(_gonder(kod));
    }
  }

  Future<void> _gonder(String kod) async {
    final ok = await Bulut.belgeYaz(_belgeAdi(kod), _metin(kod), _zaman[kod] ?? 0);
    if (ok) {
      await _bekleyenCikar(kod);
      durum.value = 'Eşitlendi';
    } else {
      durum.value = 'Çevrimdışı - internet gelince gönderilecek';
    }
  }

  /// Gönderilemeyen ayları tekrar dene (uygulama öne gelince)
  Future<void> bekleyenleriGonder() async {
    for (final kod in _bekleyenler()) {
      _yereldenOku(kod);
      await _gonder(kod);
    }
  }

  List<String> _bekleyenler() =>
      Depo.instance.prefs.getStringList(_bekleyenAnahtar) ?? const [];
  bool _bekliyor(String kod) => _bekleyenler().contains(kod);

  Future<void> _bekleyenEkle(String kod) async {
    final l = {..._bekleyenler(), kod}.toList();
    await Depo.instance.prefs.setStringList(_bekleyenAnahtar, l);
  }

  Future<void> _bekleyenCikar(String kod) async {
    final l = _bekleyenler().where((k) => k != kod).toList();
    await Depo.instance.prefs.setStringList(_bekleyenAnahtar, l);
  }

  /// Çıkışta telefondaki patron kayıtlarını temizler (bulutta kalır)
  Future<void> temizle() async {
    final prefs = Depo.instance.prefs;
    for (final k in prefs.getKeys().where((k) => k.startsWith(_onEk)).toList()) {
      await prefs.remove(k);
    }
    await prefs.remove(_bekleyenAnahtar);
    _aylar.clear();
    _zaman.clear();
    _buluttanAlinan.clear();
    notifyListeners();
  }
}
