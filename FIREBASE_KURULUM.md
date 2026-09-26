# Firebase Kurulumu (bir kerelik, ~15 dakika)

Firebase; kullanıcı girişi, verilerin buluta yedeklenmesi ve **yönetici paneli** için gerekir.
Ücretsiz "Spark" planı kullanılır. **Kredi kartı girmeyin**; girmediğiniz sürece asla fatura çıkmaz.

> Bu adımlar yapılmadan da uygulama çalışır (eskisi gibi girişsiz, sadece telefonda).

---

## 1. Proje oluştur
1. https://console.firebase.google.com adresine Google hesabınızla girin.
2. **Proje oluştur / Create a project** → ad: `puantajim` → devam.
3. Google Analytics: **kapalı** → **Proje oluştur**.

## 2. Giriş yöntemini aç
1. Sol menü **Build (Derleme) → Authentication** → **Başlayın / Get started**.
2. **Sign-in method** sekmesi → **E-posta/Şifre (Email/Password)** → **Etkinleştir** → Kaydet.
   (Telefon numarası uygulamada özetlenip e-posta biçimine çevrilir; SMS kullanılmaz, ücret çıkmaz.)
3. **Settings (Ayarlar) → Authorized domains (Yetkili alan adları)** → **Alan adı ekle**:
   `eymennegeeokurr-rgb.github.io`  (iPhone web linki için)

## 3. Veritabanını aç ve güvenlik kurallarını yükle
1. Sol menü **Build → Firestore Database** → **Veritabanı oluştur / Create database**.
2. Konum: **europe-west** (ör. `eur3` veya `europe-west3 Frankfurt`) → İleri.
3. **Production mode (üretim modu)** → Oluştur.
4. Üstte **Kurallar (Rules)** sekmesi → içindekini silin → depodaki **`firestore.rules`** dosyasının tamamını yapıştırın → **Yayınla (Publish)**.

## 4. Uygulamaları kaydet ve bilgileri al
1. Sol üst ⚙️ → **Proje ayarları (Project settings)** → aşağıda **Uygulamalarınız**.
2. **Android** simgesi → Paket adı: `com.santiye.puantajim` → **Uygulamayı kaydet**.
   `google-services.json` indirmenize **gerek yok** → İleri, İleri, **Konsola devam**.
3. **Web** simgesi `</>` → takma ad: `puantajim-web` → Firebase Hosting **işaretlemeyin** → **Kaydet**.
   Ekranda şöyle bir kod çıkar, **bunu kopyalayın**:
   ```js
   const firebaseConfig = {
     apiKey: "AIza....",
     authDomain: "puantajim-xxxx.firebaseapp.com",
     projectId: "puantajim-xxxx",
     storageBucket: "puantajim-xxxx.firebasestorage.app",
     messagingSenderId: "1234567890",
     appId: "1:1234567890:web:abcdef..."
   };
   ```
4. Proje ayarlarında Android uygulamasına tıklayın → **Uygulama kimliği (App ID)** `1:1234567890:android:....` → kopyalayın.

## 5. Bilgileri uygulamaya gir
GitHub'da **lib → firebase_ayar.dart** dosyasını açın → ✏️ kalem → tırnakların arasını doldurun:

```dart
static const apiKey = 'AIza....';
static const projectId = 'puantajim-xxxx';
static const messagingSenderId = '1234567890';
static const storageBucket = 'puantajim-xxxx.firebasestorage.app';
static const authDomain = 'puantajim-xxxx.firebaseapp.com';
static const androidAppId = '1:1234567890:android:....';
static const webAppId = '1:1234567890:web:....';
```
→ **Commit changes**. (Bu bilgiler gizli değildir; güvenliği `firestore.rules` sağlar.)

İsterseniz bu bilgileri Claude'a gönderin, dosyayı doldurulmuş olarak hazırlasın.

## 6. Kendinizi yönetici yapın
1. Yeni APK kurulunca uygulamadan **Kayıt Ol** ile kendi hesabınızı açın.
2. Firebase konsolu → **Authentication → Users (Kullanıcılar)**: listede hesabınızı görürsünüz
   (e-posta sütununda `t....@giris.puantajim.app` gibi anlamsız bir yazı olur — telefonunuz görünmez).
   Satırın sonundaki **Kullanıcı UID** değerini kopyalayın.
   (Birden fazla kayıt varsa: en son oluşturulan sizinkidir; "Oluşturulma" tarihine bakın.)
3. **Firestore Database → Veri (Data)** → **+ Koleksiyon başlat / Start collection**
   - Koleksiyon kimliği: `yoneticiler`
   - Belge kimliği: **kopyaladığınız UID**
   - Alan: `ad` (string) → kendi adınız → **Kaydet**
4. Uygulamayı kapatıp açın: Puantaj ekranının sağ üstünde **"Ekibim"** düğmesi çıkar.

## 7. Kullanım
- **Eleman**: Kayıt olur → KVKK onaylar → Profil sekmesinde **kullanıcı kodu** (`PJ-XXXX-XXXX`) görünür → size verir.
- **Siz**: Ekibim → **Personel Ekle** → kodu girin → isim çıkar → **İstek Gönder**.
- **Eleman**: Uygulamayı açınca "…puantajınızı görmek istiyor" → **Onayla**.
- **Siz**: Ekibim'de kişi görünür; dokununca puantaj, mesai, avans, hakediş, banka/elden ve notlarını görürsünüz, PDF/Excel alabilirsiniz. (Değiştiremezsiniz.)
- Eleman **Profil → İzni kaldır** ile izni istediği an geri alabilir.

## Sık sorulanlar
**Şifremi unuttum?** Kayıtta e-posta verdiyse giriş ekranında "Şifremi unuttum" → e-postasına sıfırlama bağlantısı gelir.
E-posta vermediyse: Firebase konsolu → Authentication → Users → kullanıcının satırında ⋮ → **Hesabı sil**; kişi aynı numarayla yeniden kayıt olur.
(Bu durumda eski buluttaki kayıtlar yeni hesaba geçmez; telefonunda kayıtlar duruyorsa yeni hesaba otomatik yüklenir.)

**Veriler nerede?** Firebase Firestore (Google). Telefonda da kopyası vardır; internetsiz çalışır, internet gelince eşitlenir.

**Maliyet?** 16 kişi için ücretsiz kotanın çok altında. Kredi kartı tanımlı değilse fatura çıkmaz.

**KVKK metni:** `lib/kvkk_metni.dart` içindeki `[VERİ SORUMLUSU ...]` ve `[İletişim ...]` alanlarını kendi bilgilerinizle doldurun ve metni bir hukukçuya kontrol ettirin.
