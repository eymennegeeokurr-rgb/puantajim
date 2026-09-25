import 'package:flutter/material.dart';

import '../services/guncelleme.dart';

import 'ayarlar_sayfasi.dart';
import 'hareketler_sayfasi.dart';
import 'notlar_sayfasi.dart';
import 'rapor_sayfasi.dart';
import 'takvim_sayfasi.dart';

/// Alt gezinme çubuklu ana iskelet (5 sekme).
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _secili = 0;

  @override
  void initState() {
    super.initState();
    // Açılışta (internet varsa) yeni sürüm kontrolü - sadece Android APK
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final yeni = await Guncelleme.kontrolEt();
      if (yeni != null && mounted) {
        await Guncelleme.pencereGoster(context, yeni);
      }
    });
  }

  static const _sayfalar = <Widget>[
    TakvimSayfasi(),
    HareketlerSayfasi(),
    NotlarSayfasi(),
    RaporSayfasi(),
    AyarlarSayfasi(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _secili, children: _sayfalar),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _secili,
        onDestinationSelected: (i) => setState(() => _secili = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Puantaj',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Avans',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2),
            label: 'Notlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Hakediş',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
