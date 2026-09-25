import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../platform/platform.dart' as platform;

/// Dosya paylaşma ve kaydetme (Android, iPhone web uygulaması ve tarayıcıda çalışır).
class Paylasim {
  Paylasim._();

  /// Paylaşım menüsünü açar (WhatsApp, e-posta, Drive...).
  /// [context] iPad'de menünün konumlanması için gereklidir.
  static Future<void> paylas(
    BuildContext context,
    Uint8List veri,
    String dosyaAdi,
    String mime,
    String metin,
  ) async {
    final kutu = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(veri, name: dosyaAdi, mimeType: mime)],
        fileNameOverrides: [dosyaAdi],
        text: metin,
        subject: metin,
        sharePositionOrigin:
            kutu == null ? null : kutu.localToGlobal(Offset.zero) & kutu.size,
      ),
    );
  }

  /// Cihaza kaydeder (Android: klasör seçimi, web: indirme)
  static Future<bool> kaydet(Uint8List veri, String dosyaAdi, String mime) =>
      platform.cihazaKaydet(veri, dosyaAdi, mime);

  static const pdfMime = 'application/pdf';
  static const excelMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const jsonMime = 'application/json';
}
