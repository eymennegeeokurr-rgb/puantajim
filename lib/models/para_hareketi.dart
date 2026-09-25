import 'package:flutter/material.dart';

/// Ay içindeki para hareketleri.
enum HareketTuru { avans, kesinti, ekOdeme }

extension HareketTuruX on HareketTuru {
  String get etiket => const {
        HareketTuru.avans: 'Avans',
        HareketTuru.kesinti: 'Kesinti',
        HareketTuru.ekOdeme: 'Ek Ödeme / Prim',
      }[this]!;

  String get aciklama => const {
        HareketTuru.avans: 'Alınan avans - hakedişten düşülür',
        HareketTuru.kesinti: 'Ceza, borç vb. - hakedişten düşülür',
        HareketTuru.ekOdeme: 'Prim, yol, harçlık vb. - hakedişe eklenir',
      }[this]!;

  /// Hakedişe etkisi: + ekler, - düşer
  int get isaret => this == HareketTuru.ekOdeme ? 1 : -1;

  IconData get ikon => const {
        HareketTuru.avans: Icons.payments,
        HareketTuru.kesinti: Icons.remove_circle,
        HareketTuru.ekOdeme: Icons.add_card,
      }[this]!;

  Color get renk => const {
        HareketTuru.avans: Color(0xFFEF6C00),
        HareketTuru.kesinti: Color(0xFFC62828),
        HareketTuru.ekOdeme: Color(0xFF2E7D32),
      }[this]!;

  static HareketTuru adindan(String? ad) => HareketTuru.values
      .firstWhere((t) => t.name == ad, orElse: () => HareketTuru.avans);
}

class ParaHareketi {
  final String id;
  final String tarih; // yyyy-MM-dd
  final HareketTuru tur;
  final double tutar; // Her zaman pozitif girilir
  final String aciklama;

  const ParaHareketi({
    required this.id,
    required this.tarih,
    required this.tur,
    required this.tutar,
    this.aciklama = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tarih': tarih,
        'tur': tur.name,
        'tutar': tutar,
        'aciklama': aciklama,
      };

  factory ParaHareketi.fromJson(Map<String, dynamic> j) => ParaHareketi(
        id: j['id'] as String,
        tarih: j['tarih'] as String,
        tur: HareketTuruX.adindan(j['tur'] as String?),
        tutar: (j['tutar'] as num?)?.toDouble() ?? 0,
        aciklama: (j['aciklama'] as String?) ?? '',
      );
}
