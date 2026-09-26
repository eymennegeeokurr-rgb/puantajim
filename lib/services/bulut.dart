import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/depo.dart';
import '../firebase_ayar.dart';
import '../kvkk_metni.dart';
import '../models/veri_paketi.dart';

/// Giriş yapmış kullanıcının telefonda saklanan bilgisi.
/// (Telefon numarası SAKLANMAZ.)
class Oturum {
  final String uid;
  final String adSoyad;
  final String kod; // Paylaşılan kullanıcı kodu: PJ-XXXX-XXXX

  const Oturum({required this.uid, required this.adSoyad, required this.kod});

  Map<String, dynamic> toJson() => {'uid': uid, 'adSoyad': adSoyad, 'kod': kod};

  factory Oturum.fromJson(Map<String, dynamic> j) => Oturum(
        uid: j['uid'] as String,
        adSoyad: (j['adSoyad'] as String?) ?? '',
        kod: (j['kod'] as String?) ?? '',
      );
}

/// Yönetici takip isteği (yönetici → eleman)
class Istek {
  final String id; // calisanUid_yoneticiUid
  final String calisanUid;
  final String yoneticiUid;
  final String calisanAd;
  final String yoneticiAd;
  final String durum; // bekliyor | onaylandi | reddedildi
  final int tarih;

  const Istek({
    required this.id,
    required this.calisanUid,
    required this.yoneticiUid,
    required this.calisanAd,
    required this.yoneticiAd,
    required this.durum,
    required this.tarih,
  });

  bool get bekliyor => durum == 'bekliyor';
  bool get onaylandi => durum == 'onaylandi';
  bool get reddedildi => durum == 'reddedildi';

  factory Istek.belgeden(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? const {};
    return Istek(
      id: d.id,
      calisanUid: (j['calisanUid'] as String?) ?? '',
      yoneticiUid: (j['yoneticiUid'] as String?) ?? '',
      calisanAd: (j['calisanAd'] as String?) ?? '',
      yoneticiAd: (j['yoneticiAd'] as String?) ?? '',
      durum: (j['durum'] as String?) ?? 'bekliyor',
      tarih: (j['tarih'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Kullanıcıya gösterilecek hata
class BulutHatasi implements Exception {
  final String mesaj;
  const BulutHatasi(this.mesaj);
  @override
  String toString() => mesaj;
}

/// Firebase işlemleri: giriş/kayıt, senkron, onay istekleri, yönetici paneli.
///
/// Firestore yapısı:
///   kullanicilar/{uid}              adSoyad, kod, kvkk, olusturma
///   kullanicilar/{uid}/veri/ana     veri (JSON metni), zaman, adSoyad
///   kodlar/{kod}                    uid, adSoyad   (kodla kişi bulma)
///   telefonlar/{telHash}            uid, eposta    (sadece e-posta verenler, şifre sıfırlama)
///   istekler/{calisanUid_yonUid}    calisanUid, yoneticiUid, calisanAd, yoneticiAd, durum, tarih
///   yoneticiler/{uid}               (sadece Firebase konsolundan eklenir)
class Bulut {
  Bulut._();

  static const _kOturum = 'oturum';
  static const _kVeriSahibi = 'veriSahibi';

  /// Firebase bilgileri girilmiş mi? (Girilmemişse uygulama girişsiz çalışır)
  static bool get aktif => FirebaseAyar.tamam;

  /// Firebase başarıyla başlatıldı mı? (İnternetsiz web açılışında false olabilir)
  static bool hazir = false;

  static final oturum = ValueNotifier<Oturum?>(null);
  static final yonetici = ValueNotifier<bool>(false);
  static final senkronDurumu = ValueNotifier<String>('');

  static Timer? _bekletme;
  static bool _senkronda = false;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static Depo get _depo => Depo.instance;

  // ===========================================================================
  // BAŞLATMA
  // ===========================================================================

  static Future<void> baslat() async {
    final kayitli = _depo.prefs.getString(_kOturum);
    if (kayitli != null) {
      try {
        oturum.value =
            Oturum.fromJson(jsonDecode(kayitli) as Map<String, dynamic>);
      } catch (_) {}
    }
    if (!aktif) return;

    try {
      await Firebase.initializeApp(options: FirebaseAyar.secenekler)
          .timeout(const Duration(seconds: 12));
      hazir = true;
    } catch (e) {
      hazir = false;
      debugPrint('Firebase başlatılamadı: $e');
      return;
    }

    _depo.kayitSonrasi = _degisiklikVar;

    if (oturum.value != null) {
      // Firebase oturumunun geri yüklenmesini kısa süre bekle
      try {
        await _auth.authStateChanges().first.timeout(const Duration(seconds: 6));
      } catch (_) {}
      if (_auth.currentUser?.uid == oturum.value!.uid) {
        unawaited(senkronla());
        unawaited(_yoneticiKontrol());
      }
    }
  }

  static void _oturumuKaydet(Oturum? o) {
    oturum.value = o;
    if (o == null) {
      _depo.prefs.remove(_kOturum);
    } else {
      _depo.prefs.setString(_kOturum, jsonEncode(o.toJson()));
    }
  }

  static bool get _baglanti =>
      hazir && oturum.value != null && _auth.currentUser?.uid == oturum.value!.uid;

  // ===========================================================================
  // TELEFON (numara saklanmaz, sadece geri çevrilemez özeti kullanılır)
  // ===========================================================================

  /// "0532 123 45 67", "+90 532...", "5321234567" -> "5321234567" (geçersizse null)
  static String? telefonDuzelt(String giris) {
    var t = giris.replaceAll(RegExp(r'\D'), '');
    if (t.length == 12 && t.startsWith('90')) t = t.substring(2);
    if (t.length == 11 && t.startsWith('0')) t = t.substring(1);
    if (t.length != 10 || !t.startsWith('5')) return null;
    return t;
  }

  static String _telOzeti(String tel) =>
      sha256.convert(utf8.encode('puantajim-tel:$tel')).toString();

  static String _turetilmisEposta(String telOzeti) =>
      't${telOzeti.substring(0, 40)}@giris.puantajim.app';

  // ===========================================================================
  // KAYIT / GİRİŞ / ÇIKIŞ
  // ===========================================================================

  static Future<void> kayitOl({
    required String adSoyad,
    required String telefon,
    required String sifre,
    String? eposta,
  }) async {
    _hazirMi();
    final tel = telefonDuzelt(telefon);
    if (tel == null) throw const BulutHatasi('Telefon numarası geçersiz');
    final ozet = _telOzeti(tel);
    final ePosta = (eposta != null && eposta.trim().isNotEmpty)
        ? eposta.trim().toLowerCase()
        : null;

    // Aynı numarayla e-postalı kayıt var mı?
    final var_ = await _db.collection('telefonlar').doc(ozet).get();
    if (var_.exists) {
      throw const BulutHatasi('Bu telefon numarasıyla zaten kayıt var. Giriş yapın.');
    }

    final UserCredential k;
    try {
      k = await _auth.createUserWithEmailAndPassword(
          email: ePosta ?? _turetilmisEposta(ozet), password: sifre);
    } on FirebaseAuthException catch (e) {
      throw BulutHatasi(_hataMesaji(e, kayit: true));
    }
    final uid = k.user!.uid;
    final simdi = DateTime.now().millisecondsSinceEpoch;
    final ad = adSoyad.trim();

    final kod = await _kodUret(uid, ad);
    await _db.collection('kullanicilar').doc(uid).set({
      'adSoyad': ad,
      'kod': kod,
      'olusturma': simdi,
      'kvkk': {
        'surum': KvkkMetni.surum,
        'tarih': simdi,
        'aydinlatmaVeRiza': true,
        'saglikVerisiRiza': true,
      },
    });
    if (ePosta != null) {
      await _db.collection('telefonlar').doc(ozet).set({'uid': uid, 'eposta': ePosta});
    }

    _oturumuKaydet(Oturum(uid: uid, adSoyad: ad, kod: kod));
    await senkronla();
    unawaited(_yoneticiKontrol());
  }

  static Future<void> girisYap({required String telefon, required String sifre}) async {
    _hazirMi();
    final tel = telefonDuzelt(telefon);
    if (tel == null) throw const BulutHatasi('Telefon numarası geçersiz');
    final ozet = _telOzeti(tel);

    var ePosta = _turetilmisEposta(ozet);
    try {
      final t = await _db.collection('telefonlar').doc(ozet).get();
      final e = t.data()?['eposta'] as String?;
      if (e != null && e.isNotEmpty) ePosta = e;
    } catch (_) {}

    try {
      await _auth.signInWithEmailAndPassword(email: ePosta, password: sifre);
    } on FirebaseAuthException catch (e) {
      throw BulutHatasi(_hataMesaji(e));
    }
    final uid = _auth.currentUser!.uid;
    final belge = await _db.collection('kullanicilar').doc(uid).get();
    final j = belge.data() ?? const {};
    _oturumuKaydet(Oturum(
      uid: uid,
      adSoyad: (j['adSoyad'] as String?) ?? '',
      kod: (j['kod'] as String?) ?? '',
    ));
    await senkronla();
    unawaited(_yoneticiKontrol());
  }

  /// Şifre sıfırlama e-postası gönderir (sadece kayıtta e-posta verenler)
  static Future<void> sifreSifirla(String telefon) async {
    _hazirMi();
    final tel = telefonDuzelt(telefon);
    if (tel == null) throw const BulutHatasi('Telefon numarası geçersiz');
    final t = await _db.collection('telefonlar').doc(_telOzeti(tel)).get();
    final e = t.data()?['eposta'] as String?;
    if (e == null || e.isEmpty) {
      throw const BulutHatasi(
          'Bu numara için kayıtlı e-posta yok. Şifre sıfırlamak için yöneticinizle görüşün.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: e);
    } on FirebaseAuthException catch (x) {
      throw BulutHatasi(_hataMesaji(x));
    }
  }

  /// Çıkış: önce son değişiklikleri gönderir, sonra telefondaki veriyi temizler
  static Future<void> cikisYap() async {
    if (_baglanti) {
      try {
        await senkronla();
      } catch (_) {}
    }
    try {
      if (hazir) await _auth.signOut();
    } catch (_) {}
    _oturumuKaydet(null);
    yonetici.value = false;
    await _depo.prefs.remove(_kVeriSahibi);
    await _depo.tumunuSil(bulutaBildir: false);
  }

  static void _hazirMi() {
    if (!hazir) {
      throw const BulutHatasi(
          'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edip uygulamayı yeniden açın.');
    }
  }

  static String _hataMesaji(FirebaseAuthException e, {bool kayit = false}) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu telefon numarasıyla (veya e-postayla) zaten kayıt var. Giriş yapın.';
      case 'invalid-email':
        return 'E-posta adresi geçersiz';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Telefon numarası veya şifre hatalı';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok';
      case 'operation-not-allowed':
        return 'Firebase\'de "E-posta/Şifre" girişi açılmamış (kurulum adımı 2).';
      default:
        return 'Hata: ${e.message ?? e.code}';
    }
  }

  // ===========================================================================
  // KULLANICI KODU
  // ===========================================================================

  static const _harfler = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // karışan O/0, I/1 yok

  static String _rastgeleKod() {
    final r = Random.secure();
    String parca() => List.generate(4, (_) => _harfler[r.nextInt(_harfler.length)]).join();
    return 'PJ-${parca()}-${parca()}';
  }

  static Future<String> _kodUret(String uid, String adSoyad) async {
    for (var i = 0; i < 6; i++) {
      final kod = _rastgeleKod();
      try {
        // Kural: sadece yoksa oluşturulabilir (varsa "güncelleme" sayılır ve reddedilir)
        await _db.collection('kodlar').doc(kod).set({'uid': uid, 'adSoyad': adSoyad});
        return kod;
      } catch (_) {}
    }
    throw const BulutHatasi('Kullanıcı kodu oluşturulamadı, tekrar deneyin');
  }

  /// "pj 7k3m9qx2" -> "PJ-7K3M-9QX2"
  static String kodDuzelt(String giris) {
    var t = giris.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.startsWith('PJ')) t = t.substring(2);
    if (t.length != 8) return giris.trim().toUpperCase();
    return 'PJ-${t.substring(0, 4)}-${t.substring(4)}';
  }

  // ===========================================================================
  // SENKRON (telefon <-> bulut)
  // ===========================================================================

  static void _degisiklikVar() {
    if (!_baglanti) return;
    senkronDurumu.value = 'Gönderilecek...';
    _bekletme?.cancel();
    _bekletme = Timer(const Duration(seconds: 3), () => senkronla());
  }

  static DocumentReference<Map<String, dynamic>> _veriRef(String uid) =>
      _db.collection('kullanicilar').doc(uid).collection('veri').doc('ana');

  /// Telefon ve buluttaki veriyi karşılaştırır; hangisi yeniyse diğerine yazar.
  static Future<void> senkronla() async {
    if (!_baglanti || _senkronda) return;
    _senkronda = true;
    final uid = oturum.value!.uid;
    try {
      final snap = await _veriRef(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      final bulutZaman = (snap.data()?['zaman'] as num?)?.toInt() ?? 0;
      final bulutVeri = snap.data()?['veri'] as String?;
      final yerelZaman = _depo.yerelZaman;
      final sahip = _depo.prefs.getString(_kVeriSahibi);

      if (sahip != uid) {
        // Bu telefondaki veri bu hesaba ait değil (yeni cihaz / ilk giriş)
        if (snap.exists && bulutVeri != null) {
          await _depo.buluttanUygula(bulutVeri, bulutZaman);
        } else {
          await _gonder(uid); // hesap açılmadan önceki kayıtlar buluta taşınır
        }
        await _depo.prefs.setString(_kVeriSahibi, uid);
      } else if (bulutVeri != null && bulutZaman > yerelZaman) {
        await _depo.buluttanUygula(bulutVeri, bulutZaman);
      } else if (yerelZaman > bulutZaman || !snap.exists) {
        await _gonder(uid);
      }
      senkronDurumu.value = 'Eşitlendi ${_saat()}';
    } catch (e) {
      senkronDurumu.value = 'Çevrimdışı - internet gelince gönderilecek';
      debugPrint('Senkron hatası: $e');
    } finally {
      _senkronda = false;
    }
  }

  static Future<void> _gonder(String uid) async {
    var zaman = _depo.yerelZaman;
    if (zaman == 0) zaman = DateTime.now().millisecondsSinceEpoch;
    await _veriRef(uid).set({
      'veri': _depo.paket.metin(),
      'zaman': zaman,
      'adSoyad': oturum.value?.adSoyad ?? '',
    }).timeout(const Duration(seconds: 15));
  }

  static String _saat() {
    final s = DateTime.now();
    return '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
  }

  // ===========================================================================
  // ELEMAN: gelen takip istekleri
  // ===========================================================================

  static Stream<List<Istek>> gelenIstekler() {
    if (!_baglanti) return Stream.value(const []);
    return _db
        .collection('istekler')
        .where('calisanUid', isEqualTo: oturum.value!.uid)
        .snapshots()
        .map((q) => q.docs.map(Istek.belgeden).toList()
          ..sort((a, b) => b.tarih.compareTo(a.tarih)));
  }

  static Future<void> istekCevapla(Istek i, bool onay) => _db
      .collection('istekler')
      .doc(i.id)
      .update({
        'durum': onay ? 'onaylandi' : 'reddedildi',
        'cevapTarihi': DateTime.now().millisecondsSinceEpoch,
      });

  /// Eleman izni geri alır / yönetici listeden çıkarır
  static Future<void> istekSil(Istek i) =>
      _db.collection('istekler').doc(i.id).delete();

  // ===========================================================================
  // YÖNETİCİ
  // ===========================================================================

  static Future<void> _yoneticiKontrol() async {
    if (!_baglanti) return;
    try {
      final d = await _db.collection('yoneticiler').doc(oturum.value!.uid).get();
      yonetici.value = d.exists;
    } catch (_) {}
  }

  /// Koda göre kişiyi bulur
  static Future<({String uid, String adSoyad})> kodBul(String kod) async {
    if (!_baglanti) throw const BulutHatasi('İnternet bağlantısı gerekli');
    final d = await _db.collection('kodlar').doc(kodDuzelt(kod)).get();
    if (!d.exists) throw const BulutHatasi('Bu kodla kayıtlı kişi bulunamadı');
    final j = d.data()!;
    return (uid: j['uid'] as String, adSoyad: (j['adSoyad'] as String?) ?? '');
  }

  static Future<void> istekGonder({required String calisanUid, required String calisanAd}) async {
    if (!_baglanti) throw const BulutHatasi('İnternet bağlantısı gerekli');
    final ben = oturum.value!;
    if (calisanUid == ben.uid) throw const BulutHatasi('Kendi kodunuzu ekleyemezsiniz');
    await _db.collection('istekler').doc('${calisanUid}_${ben.uid}').set({
      'calisanUid': calisanUid,
      'yoneticiUid': ben.uid,
      'calisanAd': calisanAd,
      'yoneticiAd': ben.adSoyad,
      'durum': 'bekliyor',
      'tarih': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Stream<List<Istek>> gidenIstekler() {
    if (!_baglanti) return Stream.value(const []);
    return _db
        .collection('istekler')
        .where('yoneticiUid', isEqualTo: oturum.value!.uid)
        .snapshots()
        .map((q) => q.docs.map(Istek.belgeden).toList()
          ..sort((a, b) => a.calisanAd.toLowerCase().compareTo(b.calisanAd.toLowerCase())));
  }

  /// Onay vermiş elemanın verisi (sadece okuma)
  static Future<({VeriPaketi veri, int zaman})?> personelVerisi(String uid) async {
    final d = await _veriRef(uid).get().timeout(const Duration(seconds: 15));
    final metin = d.data()?['veri'] as String?;
    if (metin == null) return null;
    return (
      veri: VeriPaketi.ayristir(metin),
      zaman: (d.data()?['zaman'] as num?)?.toInt() ?? 0,
    );
  }
}
