import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../platform/platform.dart' as platform;

/// Web sürümü tarayıcıda (ana ekrana eklenmeden) açıldıysa kurulum ipucu gösterir.
/// Android/iOS uygulamasında hiçbir şey göstermez.
class KurulumIpucu extends StatefulWidget {
  const KurulumIpucu({super.key});

  @override
  State<KurulumIpucu> createState() => _KurulumIpucuState();
}

class _KurulumIpucuState extends State<KurulumIpucu> {
  bool _kapatildi = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _kapatildi || platform.uygulamaKuruluMu) {
      return const SizedBox.shrink();
    }
    final renk = Theme.of(context).colorScheme;
    final ios = platform.iosTarayici;
    return Card(
      color: renk.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.install_mobile, color: renk.onTertiaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: renk.onTertiaryContainer, fontSize: 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Uygulama olarak ekleyin',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(ios
                        ? 'Safari\'de alttaki Paylaş (⬆) düğmesine dokunun → '
                            '"Ana Ekrana Ekle". Sonra puantajınızı HEP ana ekrandaki '
                            'simgeden açın; internetsiz de çalışır.'
                        : 'Tarayıcı menüsünden (⋮) "Ana ekrana ekle" veya '
                            '"Uygulamayı yükle"yi seçin. Sonra hep ana ekrandaki '
                            'simgeden açın; internetsiz de çalışır.'),
                    if (ios) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Önemli: Safari\'de ve ana ekran simgesinde kayıtlar ayrı tutulur.',
                        style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: renk.onTertiaryContainer,
              onPressed: () => setState(() => _kapatildi = true),
            ),
          ],
        ),
      ),
    );
  }
}
