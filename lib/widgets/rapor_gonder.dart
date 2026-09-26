import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/paylasim.dart';
import '../services/rapor_uretici.dart';

/// Dosyayı önce hazırlar, sonra "Paylaş / Kaydet" penceresi açar.
/// (iPhone web uygulamasında paylaşım, kullanıcının dokunuşuyla hemen başlamalı;
/// bu yüzden dosya önceden hazırlanır.)
Future<void> raporHazirlaVeGoster(BuildContext context, RaporUretici u,
  {required bool pdf}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  Uint8List? veri;
  Object? hata;
  try {
    veri = pdf ? await u.pdf() : u.excel();
  } catch (e) {
    hata = e;
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  if (veri == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya oluşturulamadı: $hata')));
    return;
  }

  final ad = u.dosyaAdi(pdf ? 'pdf' : 'xlsx');
  final mime = pdf ? Paylasim.pdfMime : Paylasim.excelMime;
  final dosya = veri;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(pdf ? Icons.picture_as_pdf : Icons.table_view,
                  size: 32,
                  color: pdf ? const Color(0xFFC62828) : const Color(0xFF2E7D32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${(dosya.length / 1024).toStringAsFixed(0)} KB • hazır',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Builder(
              builder: (btnCtx) => FilledButton.icon(
                onPressed: () async {
                  try {
                    await Paylasim.paylas(
                        btnCtx, dosya, ad, mime, u.paylasimMetni);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Paylaşım açılamadı, "Cihaza kaydet"i deneyin. ($e)')));
                    }
                  }
                },
                icon: const Icon(Icons.share),
                label: const Text('Paylaş (WhatsApp, e-posta...)'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await Paylasim.kaydet(dosya, ad, mime);
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dosya kaydedildi')));
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Cihaza kaydet'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    ),
  );
}
