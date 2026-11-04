import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/depo.dart';
import 'data/patron_depo.dart';
import 'platform/platform.dart' as platform;
import 'screens/ana_sayfa.dart';
import 'screens/giris_sayfasi.dart';
import 'screens/kurulum_sayfasi.dart';
import 'screens/patron_dashboard_screen.dart';
import 'services/app_mode_controller.dart';
import 'services/bulut.dart';
import 'tema.dart';

/// Puantajım — kişisel puantaj, mesai, avans ve hakediş defteri.
/// İnternetsiz çalışır; Firebase ayarlıysa girişli olur ve veriler internet
/// olduğunda buluta eşitlenir (yönetici paneli için).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  await Depo.instance.yukle();
  AppModeController.instance.yukle(Depo.instance.prefs);
  platform.kaliciDepolamaIste();
  Bulut.cikisSonrasi = () async {
    await PatronDepo.instance.temizle();
    await AppModeController.instance.sifirla();
  };
  await Bulut.baslat();
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
        // Sıra: (Firebase açıksa) giriş -> [patron modu: patron paneli]
        //       -> profil kurulumu -> ana sayfa
        home: ListenableBuilder(
          listenable: Listenable.merge([
            depo.profilVar,
            Bulut.oturum,
            AppModeController.instance.dinleyici,
          ]),
          builder: (_, __) {
            if (Bulut.aktif && Bulut.oturum.value == null) {
              return const GirisSayfasi();
            }
            if (AppModeController.instance.patronModu) {
              return const PatronDashboardScreen();
            }
            return depo.profilVar.value
                ? const AnaSayfa()
                : const KurulumSayfasi();
          },
        ),
      ),
    );
  }
}
