import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Dosyayı tarayıcı üzerinden indirir.
/// iPhone'da önizleme açılır; oradan "Dosyalar'a Kaydet" seçilebilir.
Future<bool> cihazaKaydet(Uint8List veri, String dosyaAdi, String mime) async {
  final blob = web.Blob(
    <web.BlobPart>[veri.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = dosyaAdi
    ..style.display = 'none';
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  // İndirme başlasın diye adresi biraz sonra serbest bırak
  Future<void>.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  return true;
}

/// Ana ekrana eklenmiş uygulama olarak mı açıldı?
bool get uygulamaKuruluMu {
  try {
    return web.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return true;
  }
}

/// iPhone / iPad tarayıcısı mı?
bool get iosTarayici {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
}

/// Tarayıcıdan verileri kalıcı tutmasını ister (yer darlığında silinmesin)
void kaliciDepolamaIste() {
  try {
    web.window.navigator.storage.persist();
  } catch (_) {}
}

/// Web uygulaması kendiliğinden güncellenir; güncelleme kontrolü gerekmez.
Future<String?> metinGetir(String url) async => null;
