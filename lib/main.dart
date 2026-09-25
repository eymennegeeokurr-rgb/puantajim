import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/depo.dart';
import 'platform/platform.dart' as platform;
import 'screens/ana_sayfa.dart';
import 'screens/kurulum_sayfasi.dart';
import 'tema.dart';

/// Puantajım — kişisel puantaj, mesai, avans ve hakediş defteri.
/// Tamamen çevrimdışı çalışır; veriler sadece bu cihazda tutulur.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  await Depo.instance.yukle();
  platform.kaliciDepolamaIste();
  runApp(const PuantajimUygulamasi());
}

class PuantajimUygulamasi extends StatelessWidget {
  const PuantajimUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: depo.temaModu,
      builder: (context, mod, _) => MaterialApp(
        title: 'Puantajım',
        debugShowCheckedModeBanner: false,
        theme: UygulamaTemasi.acik,
        darkTheme: UygulamaTemasi.koyu,
        themeMode: mod,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // İlk açılışta profil yoksa kurulum ekranı gösterilir
        home: ValueListenableBuilder<bool>(
          valueListenable: depo.profilVar,
          builder: (_, kurulu, __) =>
              kurulu ? const AnaSayfa() : const KurulumSayfasi(),
        ),
      ),
    );
  }
}
