import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/bicim.dart';
import '../services/bulut.dart';
import '../services/paylasim.dart';

/// Profil sayfasında: hesap bilgisi, kullanıcı kodu, senkron durumu,
/// verileri görebilen yöneticiler (onay / red / izni kaldır) ve çıkış.
class HesabimKarti extends StatefulWidget {
  const HesabimKarti({super.key});

  @override
  State<HesabimKarti> createState() => _HesabimKartiState();
}

class _HesabimKartiState extends State<HesabimKarti> {
  late final Stream<List<Istek>> _akis = Bulut.gelenIstekler();

  void _mesaj(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _cikis() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text(
            'Kayıtlarınız bulutta kalır; tekrar giriş yapınca geri gelir. '
            'Bu telefondaki kopya silinir.\n\n'
            'Not: İnternet yoksa son değişiklikleriniz gönderilemeyebilir. '
            'Çıkmadan önce internete bağlı olduğunuzdan emin olun.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çıkış Yap')),
        ],
      ),
    );
    if (onay == true) await Bulut.cikisYap();
  }

  Future<void> _izniKaldir(Istek i) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${i.yoneticiAd} artık verilerinizi görmesin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İzni Kaldır')),
        ],
      ),
    );
    if (onay == true) {
      await Bulut.istekSil(i);
      _mesaj('İzin kaldırıldı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    final o = Bulut.oturum.value;
    if (o == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Hesap ve kod
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: renk.primaryContainer,
                    child: Icon(Icons.person, color: renk.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(o.adSoyad,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text('Kullanıcı kodunuz', style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant)),
                Row(children: [
                  Expanded(
                    child: SelectableText(
                      o.kod,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: renk.primary),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kopyala',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: o.kod));
                      _mesaj('Kod kopyalandı');
                    },
                  ),
                  Builder(
                    builder: (btnCtx) => IconButton(
                      tooltip: 'Paylaş',
                      icon: const Icon(Icons.share),
                      onPressed: () => Paylasim.metinPaylas(
                        btnCtx,
                        'Puantajım kullanıcı kodum: ${o.kod}\n(${o.adSoyad})',
                        konu: 'Puantajım kodu',
                      ),
                    ),
                  ),
                ]),
                Text(
                  'Bu kodu sadece puantajınızı görmesini istediğiniz yöneticiye verin. '
                  'Kodu giren kişi, siz onaylamadan hiçbir şey göremez.',
                  style: TextStyle(fontSize: 12, color: renk.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: Bulut.senkronDurumu,
                  builder: (_, durum, __) => Row(children: [
                    Icon(
                      durum.startsWith('Eşitlendi') ? Icons.cloud_done : Icons.cloud_queue,
                      size: 18,
                      color: durum.startsWith('Eşitlendi') ? Colors.green : renk.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(durum.isEmpty ? 'Bulut: bekleniyor' : 'Bulut: $durum',
                          style: TextStyle(fontSize: 12.5, color: renk.onSurfaceVariant)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Bulut.senkronla();
                        _mesaj(Bulut.senkronDurumu.value);
                      },
                      child: const Text('Şimdi eşitle'),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),

        // ---- Verilerimi görebilenler
        StreamBuilder<List<Istek>>(
          stream: _akis,
          builder: (context, snap) {
            final liste = snap.data ?? const <Istek>[];
            final gorunen = liste.where((i) => !i.reddedildi).toList();
            if (gorunen.isEmpty) return const SizedBox.shrink();
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text('Puantajımı görebilecek yöneticiler',
                          style: TextStyle(fontWeight: FontWeight.w700, color: renk.primary)),
                    ),
                    for (final i in gorunen)
                      ListTile(
                        leading: Icon(i.onaylandi ? Icons.verified_user : Icons.help_outline,
                            color: i.onaylandi ? Colors.green : Colors.orange),
                        title: Text(i.yoneticiAd),
                        subtitle: Text(i.onaylandi
                            ? 'Görebilir (sadece okuma)'
                            : 'Onayınızı bekliyor • ${Bicim.kisaTarih(DateTime.fromMillisecondsSinceEpoch(i.tarih))}'),
                        trailing: i.onaylandi
                            ? TextButton(
                                onPressed: () => _izniKaldir(i),
                                child: const Text('İzni kaldır'))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  tooltip: 'Reddet',
                                  icon: Icon(Icons.close, color: renk.error),
                                  onPressed: () => Bulut.istekCevapla(i, false),
                                ),
                                IconButton.filled(
                                  tooltip: 'Onayla',
                                  icon: const Icon(Icons.check),
                                  onPressed: () => Bulut.istekCevapla(i, true),
                                ),
                              ]),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        Card(
          child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Çıkış yap'),
            onTap: _cikis,
          ),
        ),
      ],
    );
  }
}

/// Takvim sayfasının üstünde: onay bekleyen takip isteği varsa uyarı bandı.
class OnayBandi extends StatefulWidget {
  const OnayBandi({super.key});

  @override
  State<OnayBandi> createState() => _OnayBandiState();
}

class _OnayBandiState extends State<OnayBandi> {
  late final Stream<List<Istek>> _akis = Bulut.gelenIstekler();

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return StreamBuilder<List<Istek>>(
      stream: _akis,
      builder: (context, snap) {
        final bekleyen = (snap.data ?? const <Istek>[]).where((i) => i.bekliyor).toList();
        if (bekleyen.isEmpty) return const SizedBox.shrink();
        final i = bekleyen.first;
        return Card(
          color: renk.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.person_search, color: renk.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${i.yoneticiAd} puantajınızı görmek istiyor',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: renk.onTertiaryContainer),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Onaylarsanız puantaj, mesai, avans, hakediş ve notlarınızı görebilir '
                  '(değiştiremez). İzni istediğiniz zaman Profil sekmesinden kaldırabilirsiniz.',
                  style: TextStyle(fontSize: 12.5, color: renk.onTertiaryContainer),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Bulut.istekCevapla(i, false),
                      child: const Text('Reddet'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () => Bulut.istekCevapla(i, true),
                      child: const Text('Onayla'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
