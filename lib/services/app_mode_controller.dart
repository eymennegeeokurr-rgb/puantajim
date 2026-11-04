import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bulut.dart';

/// Uygulamanın çalışma modu.
enum AppMode {
  /// Kişi kendi puantajını, hakedişini ve avanslarını yönetir (okuma/yazma kendisinde).
  bireysel,

  /// Patron: ekibini kurar, işçilerin kodla gelen puantajını görür (salt okunur)
  /// ve hakedişi belirleyen kendi "Patron Puantajı"nı girer (okuma/yazma).
  patron,
}

extension AppModeX on AppMode {
  String get etiket => this == AppMode.bireysel ? 'Bireysel' : 'Patron';
  String get aciklama => this == AppMode.bireysel
      ? 'Kendi puantajım, hakedişim ve avanslarım'
      : 'Ekibimin günlük yoklaması ve hakedişi';
}

/// Bireysel / Patron modunu yöneten tek nokta (durum yönetimi).
///
///  - Seçilen mod telefonda saklanır.
///  - Patron modunu giriş yapmış herkes açabilir ("Patron ol"). Patron, işçi
///    onaylamadan kimsenin puantajını göremez (güvenliği Firestore kuralları sağlar).
///  - Girişsiz kullanımda [etkinMod] her zaman bireyseldir.
///  - Ekranlar [dinleyici] ile hem mod hem oturum değişimini dinler.
class AppModeController extends ValueNotifier<AppMode> {
  AppModeController._() : super(AppMode.bireysel);
  static final AppModeController instance = AppModeController._();

  static const _kMod = 'uygulamaModu';
  static const _kPatronAcildi = 'patronAcildi';

  SharedPreferences? _prefs;
  bool _secildi = false;

  /// Kullanıcı bir mod seçti mi? (ilk açılışta soru sormak için)
  bool get secildi => _secildi;

  /// Patron modu bu hesapta kullanılabilir mi? (bulut girişi gerekir)
  bool get patronKullanilabilir => Bulut.aktif && Bulut.oturum.value != null;

  /// Bu telefonda patron modu daha önce açıldı mı? (takvimde kısayol düğmesi)
  bool get patronAcildi => _prefs?.getBool(_kPatronAcildi) ?? false;

  /// Gerçekte çalışan mod
  AppMode get etkinMod =>
      value == AppMode.patron && patronKullanilabilir ? AppMode.patron : AppMode.bireysel;

  bool get patronModu => etkinMod == AppMode.patron;

  /// Mod veya yönetici yetkisi değişince haber verir
  Listenable get dinleyici => Listenable.merge([this, Bulut.oturum]);

  void yukle(SharedPreferences prefs) {
    _prefs = prefs;
    final ad = prefs.getString(_kMod);
    _secildi = ad != null;
    value = AppMode.values.firstWhere((m) => m.name == ad, orElse: () => AppMode.bireysel);
  }

  Future<void> ayarla(AppMode m) async {
    _secildi = true;
    value = m;
    await _prefs?.setString(_kMod, m.name);
    if (m == AppMode.patron) await _prefs?.setBool(_kPatronAcildi, true);
    notifyListeners();
  }

  /// Çıkışta modu sıfırla
  Future<void> sifirla() async {
    _secildi = false;
    value = AppMode.bireysel;
    await _prefs?.remove(_kMod);
    await _prefs?.remove(_kPatronAcildi);
  }
}
