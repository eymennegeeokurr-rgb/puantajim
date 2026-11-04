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
      : 'Ekibim, işçi puantajları ve patron puantajı';
}

/// Bireysel / Patron modunu yöneten tek nokta (durum yönetimi).
///
///  - Seçilen mod telefonda saklanır.
///  - Patron modu sadece yönetici hesabında kullanılabilir (yönetici yetkisi
///    Firebase konsolundan verilir). Yetki yoksa [etkinMod] her zaman bireyseldir.
///  - Ekranlar [dinleyici] ile hem mod hem yetki değişimini dinler.
class AppModeController extends ValueNotifier<AppMode> {
  AppModeController._() : super(AppMode.bireysel);
  static final AppModeController instance = AppModeController._();

  static const _kMod = 'uygulamaModu';

  SharedPreferences? _prefs;
  bool _secildi = false;

  /// Kullanıcı bir mod seçti mi? (ilk açılışta soru sormak için)
  bool get secildi => _secildi;

  /// Patron modu bu hesapta kullanılabilir mi?
  bool get patronKullanilabilir => Bulut.yonetici.value;

  /// Gerçekte çalışan mod
  AppMode get etkinMod =>
      value == AppMode.patron && patronKullanilabilir ? AppMode.patron : AppMode.bireysel;

  bool get patronModu => etkinMod == AppMode.patron;

  /// Mod veya yönetici yetkisi değişince haber verir
  Listenable get dinleyici => Listenable.merge([this, Bulut.yonetici]);

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
    notifyListeners();
  }

  /// Çıkışta modu sıfırla
  Future<void> sifirla() async {
    _secildi = false;
    value = AppMode.bireysel;
    await _prefs?.remove(_kMod);
  }
}
