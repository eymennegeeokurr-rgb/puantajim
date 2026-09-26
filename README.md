# Puantajım — Kişisel Puantaj ve Hakediş Defteri

Her çalışan kendi telefonuna kurar, **kendi** puantajını tutar:
- Her gün **Geldim / Gelmedim / İzin / Yarım gün / Tatil / Raporlu**
- İsteğe bağlı **giriş-çıkış saati** → fazla mesai otomatik önerilir
- **Avans, kesinti, ek ödeme** kayıtları
- **Not defteri**: her not o güne kaydedilir, tek tek veya aylık toplu WhatsApp'tan gönderilir
- Ay sonunda **hakediş hesabı** + **PDF / Excel** olarak WhatsApp'tan gönderme

**Sunucu yok, hesap yok, internet gerekmez.** Herkesin verisi sadece kendi telefonundadır; kimse kimsenin kaydını göremez.

| Telefon | Nasıl kurulur |
|---|---|
| **Android** | APK dosyası (veya web linki) |
| **iPhone** | Web linki → Safari → Paylaş ⬆ → **Ana Ekrana Ekle** |

İkisi de **aynı koddan** çıkar (Flutter).

---

## 0. Hesap, Bulut ve Yönetici Paneli (isteğe bağlı)

`lib/firebase_ayar.dart` doldurulursa uygulama **girişli** çalışır (kurulum: **FIREBASE_KURULUM.md**):
- Kayıt: ad soyad + cep telefonu + şifre + KVKK onayı. **Telefon numarası saklanmaz**, sadece geri çevrilemez özeti kullanılır.
- Veriler önce telefona yazılır (internetsiz çalışır), internet gelince buluta eşitlenir. Telefon değişse bile giriş yapınca kayıtlar geri gelir.
- Her kullanıcının bir **kodu** vardır (`PJ-XXXX-XXXX`). Yönetici kodu girer → elemana onay isteği gider → eleman onaylarsa yönetici puantajını **sadece görüntüler** (notlar dahil). Eleman izni istediği an kaldırabilir.
- Güvenlik `firestore.rules` ile Firebase sunucusunda sağlanır; kod/APK herkese açık olsa da başkasının verisine erişilemez.

## 1. Hesap Kuralları (aylıkçı, her ay 30 gün)

| Kalem | Hesap |
|---|---|
| Günlük ücret | Maaş ÷ 30 |
| Sayılan gün | **Sadece girilen günler**: Geldi, Ücretli İzin, Hafta Tatili, Resmi Tatil = 1 · Yarım = 0,5 · Raporlu = 1 (rapor tam ödenirse) · Gelmedi, Ücretsiz İzin, **girilmemiş gün** = 0 · Girilmemiş Pazar, o hafta çalışıldıysa otomatik hafta tatili |
| Ödenen gün | Sayılan gün toplamı (**en fazla 30**) · Şubat'ta ay sonuna kadar çalışan 30 güne tamamlanır · Ay devam ederken "şu ana kadar" hakediş görünür |
| Temel ücret | Ödenen gün × günlük ücret |
| Hafta tatili / resmi tatil / ücretli izin | Maaştan düşülmez |
| Saatlik ücret | Günlük ÷ 7,5 saat |
| Mesai ücreti | Mesai saati × saatlik × 1,5 |
| **Net (kalan alacak)** | Temel + Mesai + Ek ödeme − Avans − Kesinti |

Örnekler (45.000 ₺ maaş): 31 çeken ayda hepsi "Geldim" → 30 gün, 45.000 ₺ · 31 çeken ayda 1 gün gelmedi → yine 30 gün · 2 gün gelmedi → 29 gün · Şubat'ta tam çalıştı → 30 gün.

### Pazar ve Mesai

| Kural | Hesap |
|---|---|
| Hafta tatili (Pazar) ücreti | Her hafta 1 gün ödenir (girilmemiş pazar, o hafta çalışıldıysa kendiliğinden sayılır) |
| Pazar kesintisi (açık) | O hafta (Pzt–Cmt) mazeretsiz **"Gelmedim"** varsa o haftanın pazar ücreti ödenmez. Ücretli/ücretsiz izin, rapor, resmi tatil mazeret sayılır. (Haftalık 45 saat = 6 gün × 7,5 saat) |
| Pazar çalışması | Pazar günü "Geldim" → tatil ücretine **ek** 1 / 1,5 / **2** yevmiye (1'e 1, 1'e 1,5, **1'e 2**). Örn. günlük 1.000 ₺, 1'e 2 → 1.000 + 2.000 = 3.000 ₺ |
| Akşam (fazla) mesaisi | Saatlik (günlük ÷ 7,5) × (1 + zam) → %25 / %30 / **%50**. Örn. saatlik 100 ₺, %50 → 150 ₺ |

### Banka / Elden, Haciz, Rapor

| Kalem | Hesap |
|---|---|
| Bankaya yatan (30 gün) | **Asgari**: o yılın net asgari ücreti (2026: ₺28.075,50) · **Anlaşılan**: firma ile anlaşılan net tutar · **Yok**: hepsi elden |
| Prim günü | Ödenen gün − raporlu günler (raporlu günleri SGK öder, bankaya yatmaz) |
| Bankaya yatacak | Bankaya yatan ÷ 30 × prim günü |
| Haciz | Bankaya yatacak × 1/4 veya 1/10 → icraya gider |
| Bankaya net | Bankaya yatacak − haciz |
| Elden | Kalan alacak − bankaya yatacak |
| SGK rapor parası (tahmini) | Günlük kazanç (SGK brüt ÷ 30, en az brüt asgari/30) × 2/3 ayakta · 1/2 yatarak · hastalıkta 3. günden, iş kazasında 1. günden |
| "Raporlu günlerde maaş tam" açık | Raporlu günler maaştan düşülmez; SGK'nın ödediği tahmini tutar düşülür, farkı işveren öder |

Örnek: 45.000 ₺ maaş, bankaya 35.875,50 ₺, 30 gün tam → Banka 35.875,50 + Elden 9.124,50.
Haciz 1/4 → bankaya 26.906,63 yatar, 8.968,88 icraya gider, elden yine 9.124,50.

Yeni yılın asgari ücreti açıklanınca `lib/services/hesaplama.dart` içindeki `AsgariUcret.tablo`'ya bir satır eklenir.

7,5 saat, ×1,5 katsayı ve 1 saat mola **Profil > Mesai ayarları**'ndan değiştirilebilir.
Giriş 08:00 – Çıkış 19:00 → 11 sa − 1 mola − 7,5 normal = **2,5 saat mesai** önerilir.

---

## 2. Yayınlama — En Kolay Yol (GitHub, ücretsiz, hiçbir şey kurmadan)

Bu yol hem **APK**'yı hem de iPhone için **web linkini** otomatik üretir.

1. https://github.com adresinden ücretsiz hesap açın.
2. Sağ üst **+ > New repository** → ad: `puantajim` → **Public** → *Create*.
3. *uploading an existing file* bağlantısına tıklayın, bu klasörün **tüm içeriğini** sürükleyin → *Commit changes*.
   - `.github` klasörü gizlidir. Windows'ta görünmüyorsa: Gezgin > Görünüm > **Gizli öğeler**.
   - Sürükleyince yüklenmezse `.github/workflows/derle.yml` dosyasını *Add file > Create new file* ile aynı yola elle oluşturup içeriğini yapıştırın.
4. **Settings > Pages > Build and deployment > Source: `GitHub Actions`** seçin.
5. **Actions** sekmesi → "Derle ve Yayınla" çalışır (~8-10 dk). Çalışmıyorsa *Run workflow*'a basın.
6. Bittiğinde:
   - **Web linki:** `https://KULLANICI_ADINIZ.github.io/puantajim/`
   - **APK:** Actions > son çalışma > en altta **Puantajim-APK** → indirin, zip'ten çıkarın.

Kodu her güncellediğinizde (dosyayı yeniden yüklediğinizde) APK ve web linki otomatik yenilenir. Telefonlardaki web uygulaması bir sonraki açılışta kendini günceller, **kayıtlar silinmez**.

---

## 3. Çalışanlara Kurulum (bunu WhatsApp'tan gönderebilirsiniz)

> **iPhone:**
> 1. Bu linki **Safari** ile açın: `https://...github.io/puantajim/`
> 2. Alttaki **Paylaş (⬆)** düğmesi → **Ana Ekrana Ekle** → Ekle
> 3. Bundan sonra **hep ana ekrandaki Puantajım simgesinden** açın (Safari'den değil — kayıtlar ayrı tutulur).
> 4. İlk açılışta adınızı ve maaşınızı girin.
>
> **Android:**
> APK dosyasını açın → "Bilinmeyen kaynaklara izin ver" → Yükle.
> (veya linki Chrome'da açıp menü ⋮ → **Uygulamayı yükle / Ana ekrana ekle**)
>
> **Her gün:** Açın → **Geldim**'e basın. Mesai yaptıysanız ✎ düğmesinden saati girin.
> **Avans aldığınızda:** Avans sekmesi → Avans Ekle.
> **Ay sonunda:** Hakediş sekmesi → **PDF Gönder** → Paylaş → WhatsApp → bana gönderin.
> **Ayda bir:** Profil > **Yedek al ve gönder** → kendinize WhatsApp'tan atın (telefon bozulursa kayıtlar kurtarılır).

İlk açılışta **internet gerekir** (uygulama iner). Sonrasında internetsiz çalışır.

---

## 4. Bilgisayarda Derleme (isteğe bağlı)

1. Flutter SDK: https://docs.flutter.dev/get-started/install/windows (`C:\flutter\bin` PATH'e)
2. Android Studio (Android SDK için) → *SDK Manager > SDK Tools > Command-line Tools*
3. `flutter doctor --android-licenses` → hepsine `y`
4. **`DERLE_WINDOWS.bat`**'a çift tıklayın → APK + `build\web` klasörü çıkar.
5. Web klasörünü yayınlamak için: https://app.netlify.com/drop → `build\web` klasörünü sürükleyin → size bir link verir.

Telefonda denemek: USB hata ayıklama açık telefonla `flutter run`, tarayıcıda denemek: `flutter run -d chrome`.

---

## 5. Proje Yapısı

```
lib/
├── main.dart                   Giriş, tema, Türkçe, kurulum/ana ekran geçişi
├── tema.dart                   Material 3 açık/koyu tema (gömülü DejaVu fontu)
├── models/
│   ├── profil.dart             Ad, görev, firma, ücret tipi, mesai ayarları
│   ├── gun_kaydi.dart          Günlük durum, giriş/çıkış, mesai, not + mesai önerisi
│   └── para_hareketi.dart      Avans / kesinti / ek ödeme
├── data/depo.dart              Tüm veriler (SharedPreferences, JSON) + yedekleme
├── services/
│   ├── hesaplama.dart          Aylık hakediş hesabı (testli)
│   ├── rapor_uretici.dart      PDF (A4, imza alanlı) ve Excel (3 sayfa) üretimi
│   ├── paylasim.dart           Paylaş / cihaza kaydet
│   └── bicim.dart              Tarih, para biçimi
├── platform/                   Android ↔ web farkları (dosya indirme, kurulum tespiti)
├── widgets/                    Ay değiştirici, profil formu, "ana ekrana ekle" ipucu
└── screens/
    ├── kurulum_sayfasi.dart    İlk açılış
    ├── takvim_sayfasi.dart     Bugün kartı + aylık takvim + ay özeti
    ├── gun_duzenle_sayfasi.dart Gün düzenleme penceresi
    ├── hareketler_sayfasi.dart Avans / ödemeler
    ├── rapor_sayfasi.dart      Hakediş + PDF/Excel gönder
    └── ayarlar_sayfasi.dart    Profil, tema, yedek, sıfırlama
web/                            iPhone "Ana Ekrana Ekle" dosyaları (manifest, simge, çevrimdışı sw.js)
tool/pwa_hazirla.dart           Web derlemesinden sonra çevrimdışı önbellek listesini üretir
test/hesaplama_test.dart        Hesap testleri
.github/workflows/derle.yml     Otomatik APK + web yayını
```

## 6. Sık Sorulanlar

**Veriler nerede?** Sadece çalışanın telefonunda. Sunucuya hiçbir şey gitmez.

**iPhone'da veriler silinir mi?** Ana ekrana eklenen uygulamanın verileri kalıcıdır. Ancak uygulama simgesi silinirse veya *Ayarlar > Safari > Geçmişi ve Web Sitesi Verilerini Temizle* yapılırsa kayıtlar gider. Bu yüzden ayda bir **yedek al** önerilir.

**Telefon değişti?** Eski telefonda *Profil > Yedek al ve gönder* → yeni telefonda *Yedekten geri yükle*.

**APK "Uygulama yüklenmedi" diyor?** Güncellemeler `android_imza/debug.keystore` anahtarıyla imzalanır; bu dosyayı silmeyin/değiştirmeyin, yoksa eski sürümü kaldırmak gerekir (bu da kayıtları siler — önce yedek alın).
