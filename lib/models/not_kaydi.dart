/// Not defterindeki bir not. Bir güne birden fazla not yazılabilir.
class NotKaydi {
  final String id;
  final String tarih; // yyyy-MM-dd (notun ait olduğu gün)
  final String saat; // HH:mm (yazıldığı saat)
  final String metin;

  const NotKaydi({
    required this.id,
    required this.tarih,
    required this.saat,
    required this.metin,
  });

  /// Listede başlık olarak görünen ilk satır
  String get baslik {
    final ilk = metin.trim().split('\n').first.trim();
    return ilk.length > 60 ? '${ilk.substring(0, 60)}…' : ilk;
  }

  /// İlk satırdan sonrası (önizleme)
  String get devami {
    final satirlar = metin.trim().split('\n');
    if (satirlar.length <= 1) return '';
    return satirlar.skip(1).join('\n').trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tarih': tarih,
        'saat': saat,
        'metin': metin,
      };

  factory NotKaydi.fromJson(Map<String, dynamic> j) => NotKaydi(
        id: j['id'] as String,
        tarih: j['tarih'] as String,
        saat: (j['saat'] as String?) ?? '',
        metin: (j['metin'] as String?) ?? '',
      );
}
