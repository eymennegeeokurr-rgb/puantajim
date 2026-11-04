import 'package:flutter/material.dart';

import '../services/bulut.dart';
import '../services/guncelleme.dart';
import '../tema.dart';

import 'ayarlar_sayfasi.dart';
import 'hareketler_sayfasi.dart';
import 'notlar_sayfasi.dart';
import 'rapor_sayfasi.dart';
import 'takvim_sayfasi.dart';

/// Alt menülü ana iskelet (5 sekme): Puantaj, Avans, Notlar, Hakediş, Profil.
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with WidgetsBindingObserver {
  int _secili = 0;
  final _takvimAcik = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Açılışta (internet varsa) yeni sürüm kontrolü - sadece Android APK
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final yeni = await Guncelleme.kontrolEt();
      if (yeni != null && mounted) {
        await Guncelleme.pencereGoster(context, yeni);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _takvimAcik.dispose();
    super.dispose();
  }

  /// Uygulama arka plandan dönünce buluttaki son durumu al / bekleyenleri gönder
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Bulut.senkronla();
  }

  void _git(int i) {
    // Puantaj'a tekrar basınca (veya Hakediş'ten geri dönünce) ana sayfa açılsın
    if (i == 0 && (_secili == 0 || _secili == 3)) _takvimAcik.value = false;
    setState(() => _secili = i);
  }

  @override
  Widget build(BuildContext context) {
    final sayfalar = <Widget>[
      PuantajSekmesi(hakedisAc: () => _git(3), takvimAcik: _takvimAcik),
      const HareketlerSayfasi(),
      const NotlarSayfasi(),
      RaporSayfasi(geri: () => _git(0)),
      const AyarlarSayfasi(),
    ];
    return PopScope(
      // Puantaj dışındaki sekmede geri tuşu önce Puantaj'a döner
      canPop: _secili == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _git(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _secili, children: sayfalar),
        bottomNavigationBar: AltMenu(
          secili: _secili,
          onSec: _git,
        ),
      ),
    );
  }
}

/// Alt menü: seçili sekme yeşil, altında kısa çizgi.
class AltMenu extends StatelessWidget {
  final int secili;
  final ValueChanged<int> onSec;

  const AltMenu({super.key, required this.secili, required this.onSec});

  static const _ogeler = <(IconData?, IconData?, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Puantaj'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Avans'),
    (Icons.article_outlined, Icons.article, 'Notlar'),
    (null, null, 'Hakediş'), // ₺ simgesi yazıyla çizilir
    (Icons.person_outline, Icons.person, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Material(
      color: renk.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: renk.outlineVariant)),
          ),
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < _ogeler.length; i++)
                Expanded(child: _oge(context, i, renk)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oge(BuildContext context, int i, ColorScheme renk) {
    final (bos, dolu, etiket) = _ogeler[i];
    final aktif = i == secili;
    final r = aktif ? Renkler.yesil : renk.onSurface;
    return InkWell(
      onTap: () => onSec(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 26,
            child: bos == null
                ? Text('₺',
                    style: TextStyle(
                        fontSize: 22, height: 1.1, fontWeight: FontWeight.w700, color: r))
                : Icon(aktif ? dolu : bos, color: r, size: 25),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(etiket,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    color: r)),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: aktif ? 34 : 0,
            decoration: BoxDecoration(
              color: Renkler.yesil,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
