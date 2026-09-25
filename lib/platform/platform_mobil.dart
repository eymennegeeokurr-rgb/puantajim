import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Dosyayı telefonda kullanıcının seçtiği klasöre kaydeder (İndirilenler vb.).
Future<bool> cihazaKaydet(Uint8List veri, String dosyaAdi, String mime) async {
  final yol = await FilePicker.platform.saveFile(
    dialogTitle: 'Dosyayı kaydet',
    fileName: dosyaAdi,
    bytes: veri,
  );
  return yol != null;
}

/// Uygulama olarak mı açıldı? (Mobil derlemede her zaman evet)
bool get uygulamaKuruluMu => true;

/// iPhone/iPad tarayıcısı mı? (Mobil derlemede anlamsız)
bool get iosTarayici => false;

/// Web'de verilerin silinmemesi için kalıcı depolama izni ister (mobilde gerek yok)
void kaliciDepolamaIste() {}
