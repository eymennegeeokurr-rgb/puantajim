import 'package:flutter/material.dart';

import '../data/depo.dart';
import '../widgets/profil_formu.dart';

/// İlk açılış: kullanıcı kendi bilgilerini girer.
class KurulumSayfasi extends StatelessWidget {
  const KurulumSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: renk.primaryContainer,
                  child: Icon(Icons.edit_calendar,
                      size: 36, color: renk.onPrimaryContainer),
                ),
                const SizedBox(height: 16),
                Text('Puantajım\'a hoş geldiniz',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Her gün geldiğinizi, mesainizi ve avansınızı yazın; '
                  'ay sonunda hakedişinizi PDF veya Excel olarak gönderin.\n'
                  'Bilgileriniz sadece bu telefonda saklanır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: renk.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                ProfilFormu(
                  butonYazisi: 'Başla',
                  kaydet: Depo.instance.profilKaydet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
