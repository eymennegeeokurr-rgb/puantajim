import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase proje bilgileri.
///
/// Firebase konsolu > Proje ayarları > "Uygulamalarınız" bölümünden alınır
/// (kurulum adımları: FIREBASE_KURULUM.md).
///
/// Bu bilgiler GİZLİ DEĞİLDİR (her Firebase uygulamasının içinde bulunur).
/// Verilerin güvenliğini Firestore güvenlik kuralları sağlar (firestore.rules).
///
/// Alanlar boş bırakılırsa uygulama eskisi gibi sadece telefonda (girişsiz) çalışır.
class FirebaseAyar {
  FirebaseAyar._();

  static const apiKey = 'AIzaSyAZxt5s1rHpxmvLxygLpGdstobaINlIucs';
  static const projectId = 'puantajim-fffde';
  static const messagingSenderId = '139652556787';
  static const storageBucket = 'puantajim-fffde.firebasestorage.app';
  static const authDomain = 'puantajim-fffde.firebaseapp.com';

  /// Android uygulaması kaydedilince verilen "Uygulama kimliği" (1:...:android:...)
  static const androidAppId = '1:139652556787:android:a52c212b8218d2fe2f5486';

  /// Web uygulaması kaydedilince verilen "appId" (1:...:web:...)
  static const webAppId = '1:139652556787:web:e41bf95be8a3f3982f5486';

  static String get _appId => kIsWeb ? webAppId : androidAppId;

  /// Bilgiler girilmiş mi? (Girilmemişse bulut özellikleri kapalıdır.)
  static bool get tamam =>
      apiKey.isNotEmpty && projectId.isNotEmpty && _appId.isNotEmpty;

  static FirebaseOptions get secenekler => FirebaseOptions(
        apiKey: apiKey,
        appId: _appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        authDomain: authDomain.isEmpty ? null : authDomain,
      );
}
