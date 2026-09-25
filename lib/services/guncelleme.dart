import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform/platform.dart' as platform;

/// Uygulama içi güncelleme kontrolü (sadece Android APK).
///
/// Derleme sırasında GitHub Actions şu değerleri gömer:
///   SURUM          -> derleme numarası (her derlemede 1 artar)
///   GUNCELLEME_URL -> https://KULLANICI.github.io/DEPO/surum.json
///
/// surum.json örneği:
///   {"surum": 12, "surumAdi": "1.0.12", "apk": "https://github.com/.../Puantajim.apk",
///    "notlar": "Not defteri eklendi"}
class Guncelleme {
  Guncelleme._();

  static const surum = int.fromEnvironment('SURUM', defaultValue: 0);
  static const _url = String.fromEnvironment('GUNCELLEME_URL');

  static String get surumAdi => surum == 0 ? 'geliştirme' : '1.0.$surum';

  /// Kontrol yapılabilir mi? (Web'de gerek yok, kendiliğinden güncellenir)
  static bool get etkin => !kIsWeb && surum > 0 && _url.isNotEmpty;

  /// Yeni sürüm varsa bilgisini döner, yoksa / internet yoksa null.
  static Future<YeniSurum?> kontrolEt() async {
    if (!etkin) return null;
    final metin = await platform.metinGetir(
        '$_url?t=${DateTime.now().millisecondsSinceEpoch}');
    if (metin == null) return null;
    try {
      final j = jsonDecode(metin) as Map<String, dynamic>;
      final uzak = (j['surum'] as num?)?.toInt() ?? 0;
      final apk = j['apk'] as String?;
      if (uzak <= surum || apk == null || apk.isEmpty) return null;
      return YeniSurum(
        surum: uzak,
        surumAdi: (j['surumAdi'] as String?) ?? '1.0.$uzak',
        apkAdresi: apk,
        notlar: ((j['notlar'] as String?) ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  /// APK'yı tarayıcıda indirir (indirilince açıp "Yükle" denir)
  static Future<void> indir(YeniSurum y) async {
    await launchUrl(Uri.parse(y.apkAdresi), mode: LaunchMode.externalApplication);
  }

  /// Yeni sürüm penceresi
  static Future<void> pencereGoster(BuildContext context, YeniSurum y) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 36),
        title: Text('Yeni sürüm var: ${y.surumAdi}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (y.notlar.isNotEmpty) ...[
              Text(y.notlar, maxLines: 6, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
            ],
            const Text(
              '"Güncelle"ye basın, dosya inince açıp "Yükle" deyin.\n'
              'Kayıtlarınız silinmez.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Sonra')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              indir(y);
            },
            icon: const Icon(Icons.download),
            label: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }
}

class YeniSurum {
  final int surum;
  final String surumAdi;
  final String apkAdresi;
  final String notlar;

  const YeniSurum({
    required this.surum,
    required this.surumAdi,
    required this.apkAdresi,
    required this.notlar,
  });
}
