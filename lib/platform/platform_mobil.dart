import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Android/iOS uygulamasında "Cihaza kaydet": paylaşım menüsünü açar.
/// Menüden "Dosyalar'a kaydet", "Drive'a kaydet" veya "İndirilenler" seçilebilir.
Future<bool> cihazaKaydet(Uint8List veri, String dosyaAdi, String mime) async {
  final sonuc = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(veri, name: dosyaAdi, mimeType: mime)],
      fileNameOverrides: [dosyaAdi],
    ),
  );
  return sonuc.status == ShareResultStatus.success;
}

/// Uygulama olarak mı açıldı? (Mobil derlemede her zaman evet)
bool get uygulamaKuruluMu => true;

/// iPhone/iPad tarayıcısı mı? (Mobil derlemede anlamsız)
bool get iosTarayici => false;

/// Web'de verilerin silinmemesi için kalıcı depolama izni ister (mobilde gerek yok)
void kaliciDepolamaIste() {}
