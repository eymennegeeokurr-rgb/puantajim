import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gun_kaydi.dart';
import '../models/not_kaydi.dart';
import '../models/para_hareketi.dart';
import '../models/profil.dart';
import '../models/veri_paketi.dart';
import '../services/bicim.dart';

/// Tüm verilerin tutulduğu yer.
///
/// Veriler önce TELEFONA yazılır (SharedPreferences, JSON) - internetsiz çalışır.
/// Bulut açıksa her değişiklikten sonra [kayitSonrasi] tetiklenir ve veri
/// internet olduğunda Firebase'e gönderilir (bkz. services/bulut.dart).
class Depo extends ChangeNotifier {
  Depo._();
  static final Depo instance = Depo._();

  static const _kProfil = 'profil';
  static const _kGunler = 'gunler';
  static const _kHareketler = 'hareketler';
  static const _kNotlar = 'notlar';
  static const _kTema = 'tema';
  static const _kYerelZaman = 'yerelZaman';

  late SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;

  Profil? _profil;
  final Map<String, GunKaydi> _gunler = {};
  final List<ParaHareketi> _hareketler = [];
  final List<NotKaydi> _notlar = [];

  /// Son yerel değişikliğin zamanı (ms). Bulutla karşılaştırmada kullanılır.
  int get yerelZaman => _prefs.getInt(_kYerelZaman) ?? 0;

  /// Her kayıt değişikliğinden sonra çağrılır (bulut senkronu bağlanır)
  VoidCallback? kayitSonrasi;

  /// Tema (açık / koyu / sistem)
  final temaModu = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Profil oluşturuldu mu? (ilk açılışta kurulum ekranı gösterilir)
  final profilVar = ValueNotifier<bool>(false);

  /// Sekmeler arasında ortak seçili ay
  final seciliAy = ValueNotifier<DateTime>(
      DateTime(DateTime.now().year, DateTime.now().month));

  Profil? get profil => _profil;

  // ---------------------------------------------------------------------------
  // YÜKLEME / KAYDETME
  // ---------------------------------------------------------------------------

  Future<void> yukle() async {
    _prefs = await SharedPreferences.getInstance();
    _verileriOku();
    final tema = _prefs.getString(_kTema);
    temaModu.value = ThemeMode.values
        .firstWhere((m) => m.name == tema, orElse: () => ThemeMode.system);
  }

  void _verileriOku() {
    _profil = null;
    _gunler.clear();
    _hareketler.clear();
    _notlar.clear();

    final p = _prefs.getString(_kProfil);
    if (p != null) {
      _profil = Profil.fromJson(jsonDecode(p) as Map<String, dynamic>);
    }

    final g = _prefs.getString(_kGunler);
    if (g != null) {
      final m = jsonDecode(g) as Map<String, dynamic>;
      for (final e in m.entries) {
        _gunler[e.key] = GunKaydi.fromJson(e.value as Map<String, dynamic>);
      }
    }

    final h = _prefs.getString(_kHareketler);
    if (h != null) {
      for (final e in jsonDecode(h) as List<dynamic>) {
        _hareketler.add(ParaHareketi.fromJson(e as Map<String, dynamic>));
      }
    }

    final n = _prefs.getString(_kNotlar);
    if (n != null) {
      for (final e in jsonDecode(n) as List<dynamic>) {
        _notlar.add(NotKaydi.fromJson(e as Map<String, dynamic>));
      }
    }
    profilVar.value = _profil != null;
  }

  Future<void> _gunleriYaz() => _prefs.setString(
      _kGunler, jsonEncode(_gunler.map((k, v) => MapEntry(k, v.toJson()))));

  Future<void> _hareketleriYaz() => _prefs.setString(
      _kHareketler, jsonEncode(_hareketler.map((h) => h.toJson()).toList()));

  Future<void> _notlariYaz() => _prefs.setString(
      _kNotlar, jsonEncode(_notlar.map((n) => n.toJson()).toList()));

  /// Değişiklik oldu: zamanı işaretle, ekranları yenile, buluta haber ver
  Future<void> _degisti() async {
    await _prefs.setInt(_kYerelZaman, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
    kayitSonrasi?.call();
  }

  static String _ayOnEki(DateTime ay) =>
      '${ay.year.toString().padLeft(4, '0')}-${ay.month.toString().padLeft(2, '0')}-';

  // ---------------------------------------------------------------------------
  // PROFİL / TEMA
  // ---------------------------------------------------------------------------

  Future<void> profilKaydet(Profil p) async {
    _profil = p;
    await _prefs.setString(_kProfil, jsonEncode(p.toJson()));
    profilVar.value = true;
    await _degisti();
  }

  Future<void> temaAyarla(ThemeMode mod) async {
    temaModu.value = mod;
    await _prefs.setString(_kTema, mod.name);
  }

  // ---------------------------------------------------------------------------
  // GÜNLÜK KAYITLAR
  // ---------------------------------------------------------------------------

  GunKaydi? gun(DateTime t) => _gunler[Bicim.anahtar(t)];

  /// Seçilen ayın kayıtları (tarihe göre sıralı)
  List<GunKaydi> ayKayitlari(DateTime ay) {
    final onEk = _ayOnEki(ay);
    final l = _gunler.values.where((k) => k.tarih.startsWith(onEk)).toList()
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    return l;
  }

  Future<void> gunKaydet(GunKaydi k) async {
    _gunler[k.tarih] = k;
    await _gunleriYaz();
    await _degisti();
  }

  Future<void> gunSil(String tarih) async {
    _gunler.remove(tarih);
    await _gunleriYaz();
    await _degisti();
  }

  // ---------------------------------------------------------------------------
  // AVANS / KESİNTİ / EK ÖDEME
  // ---------------------------------------------------------------------------

  List<ParaHareketi> ayHareketleri(DateTime ay) {
    final onEk = _ayOnEki(ay);
    final l = _hareketler.where((h) => h.tarih.startsWith(onEk)).toList()
      ..sort((a, b) => a.tarih.compareTo(b.tarih));
    return l;
  }

  /// Aynı id varsa günceller, yoksa ekler
  Future<void> hareketKaydet(ParaHareketi h) async {
    final i = _hareketler.indexWhere((x) => x.id == h.id);
    if (i >= 0) {
      _hareketler[i] = h;
    } else {
      _hareketler.add(h);
    }
    await _hareketleriYaz();
    await _degisti();
  }

  Future<void> hareketSil(String id) async {
    _hareketler.removeWhere((h) => h.id == id);
    await _hareketleriYaz();
    await _degisti();
  }

  // ---------------------------------------------------------------------------
  // NOT DEFTERİ
  // ---------------------------------------------------------------------------

  /// Seçilen ayın notları (tarihe, sonra saate göre sıralı - eskiden yeniye)
  List<NotKaydi> ayNotlari(DateTime ay) {
    final onEk = _ayOnEki(ay);
    final l = _notlar.where((n) => n.tarih.startsWith(onEk)).toList()
      ..sort((a, b) {
        final t = a.tarih.compareTo(b.tarih);
        return t != 0 ? t : a.saat.compareTo(b.saat);
      });
    return l;
  }

  /// O güne ait not var mı? (takvimde işaret için)
  bool notVar(DateTime t) {
    final anahtar = Bicim.anahtar(t);
    return _notlar.any((n) => n.tarih == anahtar);
  }

  /// Aynı id varsa günceller, yoksa ekler
  Future<void> notKaydet(NotKaydi n) async {
    final i = _notlar.indexWhere((x) => x.id == n.id);
    if (i >= 0) {
      _notlar[i] = n;
    } else {
      _notlar.add(n);
    }
    await _notlariYaz();
    await _degisti();
  }

  Future<void> notSil(String id) async {
    _notlar.removeWhere((n) => n.id == id);
    await _notlariYaz();
    await _degisti();
  }

  // ---------------------------------------------------------------------------
  // TÜM VERİ (yedek + bulut)
  // ---------------------------------------------------------------------------

  VeriPaketi get paket => VeriPaketi(
        profil: _profil,
        gunler: _gunler.values.toList(),
        hareketler: List.of(_hareketler),
        notlar: List.of(_notlar),
      );

  /// Veri hiç girilmemiş mi? (yeni kurulum)
  bool get bos => paket.bos;

  /// Tüm verileri tek JSON metni olarak verir (yedek dosyası)
  String yedekOlustur() => paket.metin(girintili: true);

  Future<void> _paketiYaz(VeriPaketi v) async {
    if (v.profil != null) {
      await _prefs.setString(_kProfil, jsonEncode(v.profil!.toJson()));
    } else {
      await _prefs.remove(_kProfil);
    }
    await _prefs.setString(
        _kGunler, jsonEncode({for (final g in v.gunler) g.tarih: g.toJson()}));
    await _prefs.setString(
        _kHareketler, jsonEncode(v.hareketler.map((h) => h.toJson()).toList()));
    await _prefs.setString(
        _kNotlar, jsonEncode(v.notlar.map((n) => n.toJson()).toList()));
    _verileriOku();
  }

  /// Yedekten geri yükler. Hatalı dosyada istisna fırlatır, mevcut veri bozulmaz.
  Future<void> yedektenYukle(String metin) async {
    final v = VeriPaketi.ayristir(metin); // önce tamamen ayrıştır
    await _paketiYaz(VeriPaketi(
      profil: v.profil ?? _profil, // yedekte profil yoksa mevcut kalsın
      gunler: v.gunler,
      hareketler: v.hareketler,
      notlar: v.notlar,
    ));
    await _degisti();
  }

  /// Buluttan gelen veriyi uygular (bulut daha yeniyse). Buluta geri göndermez.
  Future<void> buluttanUygula(String metin, int zaman) async {
    final v = VeriPaketi.ayristir(metin);
    await _paketiYaz(v);
    await _prefs.setInt(_kYerelZaman, zaman);
    notifyListeners();
  }

  /// Her şeyi siler (profil dahil) - kurulum ekranına döner
  Future<void> tumunuSil({bool bulutaBildir = true}) async {
    await _prefs.remove(_kProfil);
    await _prefs.remove(_kGunler);
    await _prefs.remove(_kHareketler);
    await _prefs.remove(_kNotlar);
    _verileriOku();
    if (bulutaBildir) {
      await _degisti();
    } else {
      await _prefs.remove(_kYerelZaman);
      notifyListeners();
    }
  }
}
