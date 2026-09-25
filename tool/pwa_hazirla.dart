// Web derlemesinden sonra çalıştırılır:
//   flutter build web --release --no-web-resources-cdn
//   dart run tool/pwa_hazirla.dart
//
// build/web içindeki tüm dosyaları listeleyip sw.js'e yazar ve yeni bir sürüm
// numarası verir. Böylece uygulama ilk açılışta tamamen önbelleğe alınır ve
// internet olmadan çalışır; her yeni derleme telefonlarda otomatik güncellenir.

import 'dart:convert';
import 'dart:io';

void main() {
  final kok = Directory('build/web');
  final sw = File('build/web/sw.js');
  if (!kok.existsSync() || !sw.existsSync()) {
    stderr.writeln('build/web/sw.js bulunamadı. Önce "flutter build web" çalıştırın.');
    exit(1);
  }

  final atla = {'sw.js', 'flutter_service_worker.js', 'version.json', '.last_build_id'};
  final dosyalar = <String>[];
  for (final f in kok.listSync(recursive: true).whereType<File>()) {
    final yol = f.path
        .substring(kok.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (atla.contains(yol) || yol.endsWith('.map') || yol.endsWith('.symbols')) {
      continue;
    }
    dosyalar.add(yol);
  }
  dosyalar.sort();

  final surum = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
  var icerik = sw.readAsStringSync();
  icerik = icerik
      .replaceFirst("const SURUM = 'gelistirme';", "const SURUM = '$surum';")
      .replaceFirst('const DOSYALAR = [];', 'const DOSYALAR = ${jsonEncode(dosyalar)};');
  sw.writeAsStringSync(icerik);

  stdout.writeln('sw.js hazır: ${dosyalar.length} dosya, sürüm $surum');
}
