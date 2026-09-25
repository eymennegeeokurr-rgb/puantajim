import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gun_kaydi.dart';
import '../models/not_kaydi.dart';
import '../models/para_hareketi.dart';
import '../models/profil.dart';
import '../services/bicim.dart';

/// Tüm verilerin tutulduğu yer (tek kullanıcı, tamamen telefonda).
///
/// Veriler JSON olarak SharedPreferences'ta saklanır:
///  - Android: uygulamanın özel hafızası
///  - iPhone (ana ekrana eklenen web uygulaması): tarayıcının yerel hafızası
///
/// Bir kişinin yıllarca tuttuğu puantaj bile birkaç yüz KB'ı geçmez.
class Depo extends ChangeNotifier {
  Depo._();
  static final Depo instance = Depo._();

  static const _kProfil = 'profil';
  static const _kGunler = 'gunler';
  static const _kHareketler = 'hareketler';
  static const _kNotlar = 'notlar';
  static const _kTema = 'tema';
  static const yedekSurumu = 1;

  late SharedPreferences _prefs;

  Profil? _profil;
  final Map<String, GunKaydi> _gunler = {};
  final List<ParaHareketi> _hareketler = [];
  final List<NotKaydi> _notlar = [];

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

  static String _ayOnEki(DateTime ay) =>
      '${ay.year.toString().padLeft(4, '0')}-${ay.month.toString().padLeft(2, '0')}-';

  // ---------------------------------------------------------------------------
  // PROFİL / TEMA
  // ---------------------------------------------------------------------------

  Future<void> profilKaydet(Profil p) async {
    _profil = p;
    await _prefs.setString(_kProfil, jsonEncode(p.toJson()));
    profilVar.value = true;
    notifyListeners();
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
    notifyListeners();
    await _gunleriYaz();
  }

  Future<void> gunSil(String tarih) async {
    _gunler.remove(tarih);
    notifyListeners();
    await _gunleriYaz();
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
    notifyListeners();
    await _hareketleriYaz();
  }

  Future<void> hareketSil(String id) async {
    _hareketler.removeWhere((h) => h.id == id);
    notifyListeners();
    await _hareketleriYaz();
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
    notifyListeners();
    await _notlariYaz();
  }

  Future<void> notSil(String id) async {
    _notlar.removeWhere((n) => n.id == id);
    notifyListeners();
    await _notlariYaz();
  }

  // ---------------------------------------------------------------------------
  // YEDEKLEME
  // ---------------------------------------------------------------------------

  /// Tüm verileri tek JSON metni olarak verir
  String yedekOlustur() => const JsonEncoder.withIndent(' ').convert({
        'uygulama': 'puantajim',
        'surum': yedekSurumu,
        'tarih': DateTime.now().toIso8601String(),
        'profil': _profil?.toJson(),
        'gunler': _gunler.values.map((g) => g.toJson()).toList(),
        'hareketler': _hareketler.map((h) => h.toJson()).toList(),
        'notlar': _notlar.map((n) => n.toJson()).toList(),
      });

  /// Yedekten geri yükler. Hatalı dosyada istisna fırlatır, mevcut veri bozulmaz.
  Future<void> yedektenYukle(String metin) async {
    final j = jsonDecode(metin);
    if (j is! Map<String, dynamic> || j['uygulama'] != 'puantajim') {
      throw const FormatException('Bu dosya bir Puantajım yedeği değil');
    }
    // Önce tamamen ayrıştır, hata yoksa yaz
    final profil = j['profil'] == null
        ? null
        : Profil.fromJson(j['profil'] as Map<String, dynamic>);
    final gunler = (j['gunler'] as List<dynamic>? ?? [])
        .map((e) => GunKaydi.fromJson(e as Map<String, dynamic>))
        .toList();
    final hareketler = (j['hareketler'] as List<dynamic>? ?? [])
        .map((e) => ParaHareketi.fromJson(e as Map<String, dynamic>))
        .toList();
    final notlar = (j['notlar'] as List<dynamic>? ?? [])
        .map((e) => NotKaydi.fromJson(e as Map<String, dynamic>))
        .toList();

    if (profil != null) {
      await _prefs.setString(_kProfil, jsonEncode(profil.toJson()));
    }
    await _prefs.setString(_kGunler,
        jsonEncode({for (final g in gunler) g.tarih: g.toJson()}));
    await _prefs.setString(_kHareketler,
        jsonEncode(hareketler.map((h) => h.toJson()).toList()));
    await _prefs.setString(
        _kNotlar, jsonEncode(notlar.map((n) => n.toJson()).toList()));
    _verileriOku();
    notifyListeners();
  }

  /// Her şeyi siler (profil dahil) - kurulum ekranına döner
  Future<void> tumunuSil() async {
    await _prefs.remove(_kProfil);
    await _prefs.remove(_kGunler);
    await _prefs.remove(_kHareketler);
    await _prefs.remove(_kNotlar);
    _verileriOku();
    notifyListeners();
  }
}
