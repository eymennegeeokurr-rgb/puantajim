/// KVKK Aydınlatma Metni ve Açık Rıza metinleri.
///
/// ÖNEMLİ: Bu metin bir ŞABLONDUR. Kullanmadan önce [VERİ SORUMLUSU] bilgilerini
/// kendi bilgilerinizle doldurun ve bir hukukçu / mali müşavire kontrol ettirin.
/// Metni değiştirirseniz [surum] değerini artırın; kullanıcılar yeni metni
/// tekrar onaylar.
class KvkkMetni {
  KvkkMetni._();

  static const surum = 'v1';

  /// Veri sorumlusu (işveren) - kendi bilginizle değiştirin
  static const veriSorumlusu = '[VERİ SORUMLUSU: Ad Soyad / Firma Unvanı]';
  static const iletisim = '[İletişim: telefon veya e-posta]';

  static const baslik = 'Kişisel Verilerin Korunması Aydınlatma Metni';

  static const aydinlatma = '''
6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, $veriSorumlusu olarak kişisel verilerinizi aşağıda açıklanan şekilde işlemekteyiz.

1. İşlenen Kişisel Veriler
• Kimlik: Ad soyad
• Hesap: Telefon numaranızdan üretilen geri çevrilemez giriş anahtarı (telefon numaranızın kendisi saklanmaz), isteğe bağlı e-posta adresi
• Çalışma kayıtları: Puantaj (geldi / gelmedi / izin / yarım gün / tatil), giriş-çıkış saatleri, fazla mesai, pazar çalışması, notlar
• Finansal: Maaş, bankaya yatan tutar, avans, kesinti, ek ödeme, haciz (icra) kesinti oranı, hakediş hesapları
• Sağlık (özel nitelikli): Raporlu günler ve rapor türü (ayakta / yatarak / iş kazası)

2. İşleme Amaçları
• Puantaj, fazla mesai ve hakedişinizin hesaplanması ve size raporlanması
• Onay verdiğiniz takdirde bu bilgilerin işvereninizle / yöneticinizle paylaşılması
• Telefonunuz değişse veya bozulsa bile kayıtlarınızın korunması (bulut yedeği)

3. Aktarım
Verileriniz, Google LLC tarafından sağlanan Firebase bulut hizmetinde saklanır. Bu hizmetin sunucuları yurt dışında bulunabilir; bu aktarım için açık rızanız alınmaktadır. Verileriniz, SİZ ONAY VERMEDİKÇE hiçbir yöneticiyle paylaşılmaz. Verdiğiniz onayı uygulama içinden istediğiniz zaman geri alabilirsiniz.

4. Toplama Yöntemi ve Hukuki Sebep
Veriler, bu uygulamaya sizin tarafınızdan girilerek elektronik ortamda toplanır. Hukuki sebepler: iş sözleşmesinin ifası (KVKK m.5/2-c), veri sorumlusunun hukuki yükümlülüğü (m.5/2-ç) ve sağlık verileri ile yurt dışı aktarım için açık rızanız (m.6, m.9).

5. Saklama Süresi
Verileriniz, hesabınızı silene kadar veya ilgili mevzuatta öngörülen süre boyunca saklanır.

6. Haklarınız (KVKK m.11)
Kişisel verilerinizin işlenip işlenmediğini öğrenme, bilgi talep etme, düzeltilmesini veya silinmesini isteme, aktarıldığı kişileri bilme, itiraz etme ve zarara uğramanız halinde tazminat talep etme haklarına sahipsiniz. Başvuru: $iletisim
''';

  static const riza1 =
      'Aydınlatma Metnini okudum; kişisel verilerimin (puantaj, mesai, maaş, '
      'avans, haciz, notlar) işlenmesine, yurt dışındaki bulut sunucularında '
      'saklanmasına açık rıza veriyorum.';

  static const riza2 =
      'Raporlu günlerime ve rapor türüne ilişkin sağlık verilerimin (özel '
      'nitelikli kişisel veri) hakediş hesabı amacıyla işlenmesine açık rıza '
      'veriyorum.';
}
